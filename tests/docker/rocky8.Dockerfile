# vim 8.0.1763, tmux 2.7 (RHEL 8)
FROM rockylinux:8
RUN dnf -y install vim-enhanced tmux git && dnf clean all
