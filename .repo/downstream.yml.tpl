##[>] 🤖
downstream:
  - uri: us-central1-docker.pkg.dev/staging-499418/ci/sandbox
    type: ociImage
    versionEnvVar: AI_SANDBOX_REF
    version: {{ env.Getenv "AI_SANDBOX_REF" }}
##[<] 🤖
