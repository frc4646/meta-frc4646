do_install:append() {
    install -m 644 ${S}/contrib/completion/git-prompt.sh ${D}/${datadir}/bash-completion/completions/git-prompt.sh  
}
