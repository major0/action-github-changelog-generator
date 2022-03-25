FROM githubchangeloggenerator/github-changelog-generator:1.16.4

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
