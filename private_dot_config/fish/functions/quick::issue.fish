function quick::issue --description "Triage an issue with codex (DeepSeek): init, codex, push, open"
    if test (count $argv) -ne 1
        echo "Usage: quick::issue <ISSUE-URL|N>" >&2
        return 1
    end

    issue::triage::init $argv[1]
    or return 1

    issue::triage::codex --deepseek
    issue::triage::push
    or return 1
    issue::triage::open
end
