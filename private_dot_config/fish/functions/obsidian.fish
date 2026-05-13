function obsidian
    set -l sock_src /run/user/1000/.flatpak/md.obsidian.Obsidian/xdg-run/.obsidian-cli.sock
    set -l sock_dst /run/user/1000/.obsidian-cli.sock
    if test -S $sock_src; and not test -e $sock_dst
        ln -sf $sock_src $sock_dst
    end
    command ~/.local/bin/obsidian $argv
end
