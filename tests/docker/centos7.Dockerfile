# vim 7.4.629: no packages (tier 0 + own plugin/ files only), tmux 1.8
FROM centos:7
RUN sed -i -e 's/^mirrorlist/#mirrorlist/' -e 's|^#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|' /etc/yum.repos.d/CentOS-*.repo \
 && yum -y install vim-enhanced tmux git && yum clean all
ENV LC_ALL=en_US.UTF-8
