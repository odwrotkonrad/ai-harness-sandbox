##[>] 🤖🤖
FROM registry.gitlab.com/konradodwrot/sandbox/dev-sandbox:v0.0.1

#[why] build context is the local configs checkout; bake it where the host keeps it
COPY --chown=ko:ko . /home/ko/projects/gitlab/konradodwrot/configs

#[why] same flow configs' run-repo-ci-virt-linux-test proves in a container: secrets skipped, cli/linux profile forced
RUN sudo -u ko sh -c 'cd /home/ko/projects/gitlab/konradodwrot/configs && CI=1 MK_DRY_RUN_RENDER_SECRETS=true CHE_PROFILES_FORCE_ONE=cli/linux make run-sync-full'

USER ko
WORKDIR /home/ko
CMD ["zsh", "-l"]
##[<] 🤖🤖
