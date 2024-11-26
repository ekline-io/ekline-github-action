import { Octokit } from "@octokit/rest";
(
    async function main() {
        const username = process.env['GITHUB_TRIGGERING_ACTOR']

        if (!username) {
          console.error("GITHUB_TRIGGERING_ACTOR is not set");
          process.exit(1);
        }

        const octokit = new Octokit();

        try {
          const { data } = await octokit.users.getByUsername({
            username: username,
          });
          console.log(data.id);
        } catch (error) {
          console.error("Failed to get user ID:", error);
          process.exit(1);
        }
      }
)();
