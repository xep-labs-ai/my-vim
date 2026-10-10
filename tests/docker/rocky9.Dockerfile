# vim 8.2.2637, tmux 3.2a (RHEL 9)
FROM rockylinux:9
RUN dnf -y install vim-enhanced tmux git && dnf clean all
