# ~/.bashrc: executed by bash(1) for non-login shells.

# Note: PS1 is set in /etc/profile, and the default umask is defined
# in /etc/login.defs. You should not need this unless you want different
# defaults for root.
# PS1='${debian_chroot:+($debian_chroot)}\h:\w\$ '
# umask 022

# You may uncomment the following lines if you want `ls' to be colorized:
# export LS_OPTIONS='--color=auto'
# eval "$(dircolors)"
# alias ls='ls $LS_OPTIONS'
# alias ll='ls $LS_OPTIONS -l'
# alias l='ls $LS_OPTIONS -lA'
#
# Some more alias to avoid making mistakes:
# alias rm='rm -i'
# alias cp='cp -i'
# alias mv='mv -i'
#export ANTHROPIC_BASE_URL=https://crs.cnmpdd.com/api
#export ANTHROPIC_BASE_URL=https://relay01.yhlxj.com
export ANTHROPIC_BASE_URL=https://c.cspok.cn
export ANTHROPIC_AUTH_TOKEN=sk-FqRXINPMY6zY4RpXp0WMtNMKQRMJjbZsuZ7axwFm9tQg23P4
#export ANTHROPIC_AUTH_TOKEN=sk-TU9PnrcUHduE198IEh3SZdle9j5hHHPFPqxl1lLnT6IjnmJn
#export ANTHROPIC_AUTH_TOKEN=sk-OyxArRtTIT2BL3zBhuStHApWdBQqEvvA84Mkq3HcmyQyS5bz
#export ANTHROPIC_AUTH_TOKEN=sk-ant-sid01--ce902d37841731b81e0e28bdaabc6b9276912a6e9ce497989f128f8bf2b0439a
#export ANTHROPIC_AUTH_TOKEN=cr_85f79e967a3a1da9bafe6aae273453c362a93993cd4a245b046007e6b95db61d
#source /etc/bash_completion.d/kubectl
source /usr/share/bash-completion/bash_completion
alias ls='ls --color=auto'
alias ll='ls --color=auto -lAF'
PS1='\[\033[01;31m\]\u\[\033[01;33m\]@\[\033[01;36m\]\h \[\033[01;33m\]\w \[\033[01;35m\]\$ \[\033[00m\]'
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
#export LANG=zh_HK.utf8
#export LC_ALL=zh_HK.utf8
