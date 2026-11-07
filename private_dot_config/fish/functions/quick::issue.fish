function quick::issue --description "Triage an issue with codex (DeepSeek): init, codex, push, open (confirm)"
    if test (count $argv) -ne 1
        echo "Usage: quick::issue <ISSUE-URL|N>" >&2
        return 1
    end

    issue::triage::init $argv[1]
    or return 1

    issue::triage::codex --deepseek
    issue::triage::push
    or return 1
    read --nchars 1 --prompt-str "Open in browser? [Y/n] " answer
    if not string match -qi n -- "$answer"
        issue::triage::open
    end
end
