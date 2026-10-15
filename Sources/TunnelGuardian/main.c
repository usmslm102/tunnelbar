// Own one child process group. Closing stdin (including parent SIGKILL) stops it.
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <spawn.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/event.h>
#include <sys/wait.h>
#include <unistd.h>

extern char **environ;

static void reap_after_kill(pid_t child) {
    kill(-child, SIGKILL);
    while (waitpid(child, NULL, 0) < 0 && errno == EINTR) {}
}

int main(int argc, char **argv) {
    if (argc < 2 || argv[1][0] != '/') {
        fprintf(stderr, "TunnelGuardian requires an absolute executable path.\n");
        return 64;
    }
    signal(SIGTERM, SIG_IGN);
    signal(SIGINT, SIG_IGN);
    signal(SIGPIPE, SIG_IGN);
    int queue = kqueue();
    if (queue < 0) { perror("kqueue"); return 70; }
    struct kevent initial[3];
    EV_SET(&initial[0], STDIN_FILENO, EVFILT_READ, EV_ADD, 0, 0, NULL);
    EV_SET(&initial[1], SIGTERM, EVFILT_SIGNAL, EV_ADD, 0, 0, NULL);
    EV_SET(&initial[2], SIGINT, EVFILT_SIGNAL, EV_ADD, 0, 0, NULL);
    if (kevent(queue, initial, 3, NULL, 0, NULL) < 0) { perror("kevent"); close(queue); return 70; }
    fcntl(queue, F_SETFD, FD_CLOEXEC);

    posix_spawnattr_t attr;
    posix_spawn_file_actions_t actions;
    posix_spawnattr_init(&attr);
    posix_spawn_file_actions_init(&actions);
    sigset_t defaults, mask;
    sigemptyset(&defaults);
    sigaddset(&defaults, SIGTERM);
    sigaddset(&defaults, SIGINT);
    sigaddset(&defaults, SIGPIPE);
    sigemptyset(&mask);
    posix_spawnattr_setsigdefault(&attr, &defaults);
    posix_spawnattr_setsigmask(&attr, &mask);
    posix_spawnattr_setpgroup(&attr, 0);
    posix_spawnattr_setflags(&attr, POSIX_SPAWN_SETPGROUP | POSIX_SPAWN_SETSIGDEF | POSIX_SPAWN_SETSIGMASK);
    posix_spawn_file_actions_addopen(&actions, STDIN_FILENO, "/dev/null", O_RDONLY, 0);
    pid_t child;
    int error = posix_spawn(&child, argv[1], &actions, &attr, argv + 1, environ);
    posix_spawnattr_destroy(&attr);
    posix_spawn_file_actions_destroy(&actions);
    if (error) { errno = error; perror("launch child"); close(queue); return 127; }

    struct kevent watch;
    EV_SET(&watch, child, EVFILT_PROC, EV_ADD | EV_ONESHOT, NOTE_EXIT, 0, NULL);
    if (kevent(queue, &watch, 1, NULL, 0, NULL) < 0) {
        // The child may already have exited. Reap it, or fail closed on watch errors.
        int status;
        if (waitpid(child, &status, WNOHANG) == child) {
            close(queue);
            return WIFEXITED(status) ? WEXITSTATUS(status) : 128 + WTERMSIG(status);
        }
        reap_after_kill(child); close(queue); return 70;
    }

    int stopping = 0;
    while (1) {
        struct kevent event;
        if (kevent(queue, NULL, 0, &event, 1, NULL) < 0) {
            if (errno == EINTR) continue;
            reap_after_kill(child); close(queue); return 70;
        }
        if (event.filter == EVFILT_PROC) {
            // The zombie still reserves the PID, so cleanup cannot hit a reused group.
            kill(-child, SIGKILL);
            int status;
            while (waitpid(child, &status, 0) < 0) {
                if (errno != EINTR) { close(queue); return 70; }
            }
            close(queue);
            return WIFEXITED(status) ? WEXITSTATUS(status) : 128 + WTERMSIG(status);
        }
        if (event.filter == EVFILT_TIMER) {
            reap_after_kill(child); close(queue); return 128 + SIGKILL;
        }
        if (!stopping && (event.filter == EVFILT_SIGNAL ||
                          (event.filter == EVFILT_READ && (event.flags & EV_EOF)))) {
            stopping = 1;
            kill(-child, SIGTERM);
            EV_SET(&watch, STDIN_FILENO, EVFILT_READ, EV_DELETE, 0, 0, NULL);
            kevent(queue, &watch, 1, NULL, 0, NULL);
            EV_SET(&watch, 1, EVFILT_TIMER, EV_ADD | EV_ONESHOT, 0, 3000, NULL);
            if (kevent(queue, &watch, 1, NULL, 0, NULL) < 0) {
                reap_after_kill(child); close(queue); return 70;
            }
        }
    }
}
