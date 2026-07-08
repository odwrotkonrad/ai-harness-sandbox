##[>] 🤖🤖
FROM registry.gitlab.com/konradodwrot/sandbox/dev-sandbox:v0.0.1

#[why] build context is the local configs checkout; bake it where the host keeps it (run-image-build.zsh derives the path)
ARG CONFIGS_BAKE_DIR=/home/ko/configs
COPY --chown=ko:ko . $CONFIGS_BAKE_DIR

#[why] same flow configs' run-repo-ci-virt-linux-test proves in a container: secrets skipped, cli/linux profile forced
RUN sudo -u ko sh -c "cd $CONFIGS_BAKE_DIR && CI=1 MK_DRY_RUN_RENDER_SECRETS=true CHE_PROFILE=cli/linux make run-sync-full"

USER ko
WORKDIR /home/ko
CMD ["zsh", "-l"]
##[<] 🤖🤖
