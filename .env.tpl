##[>] 🤖🤖
{{ localFile ".repo/upstream.env" | alwaysUpdate }}
SESSION=
SESSION_NEW=
SESSION_STOPPED=
ARTIFACT_REGISTRY={{ shell "glab variable get -g konradodwrot GRP_KO_VAR_ARTIFACT_REGISTRY" }}
##[<] 🤖🤖
