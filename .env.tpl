##[>] 🤖🤖
{{ localFile ".repo/upstream.env" | alwaysUpdate }}
SESSION=
SESSION_NEW=
SESSION_STOPPED=
AUTOMATION_REF={{ shell "glab variable get -g konradodwrot GRP_KO_VAR_AUTOMATION_REF" }}
ARTIFACT_REGISTRY={{ shell "glab variable get -g konradodwrot GRP_KO_VAR_ARTIFACT_REGISTRY" }}
##[<] 🤖🤖
