import { Octokit } from '@octokit/rest';
import { existsSync, statSync } from 'fs';

const issueNumber = parseInt(process.env['PULL_REQUEST_ID'] || '', 10);
const jobId = process.env['EXTERNAL_JOB_ID'];
const githubToken = process.env['INPUT_GITHUB_TOKEN'];
const eklineAppURL = process.env['EKLINE_APP_URL'];
const repository = process.env['REPOSITORY'];
const repositoryOwner = process.env['REPOSITORY_OWNER'];

const searchTitle = 'EkLine Reviewer';
const searchString = `### 🌟 **EkLine Reviewer**

Hello! I’m here to help improve your docs. I’ve reviewed your pull request, and left in-line suggestions for quick fixes. For details, visit the [Analytics Page](<link>).

For questions or feedback, please email [support@ekline.io](mailto:support@ekline.io).`;

const positiveString = `### 🌟 **EkLine Reviewer**

I've reviewed your pull request and found no issues with your documentation. Great work! 🎉 

For questions or feedback, please email [support@ekline.io](mailto:support@ekline.io).`;

const octokit = new Octokit({
  auth: githubToken,
});

const getCommentId = async (owner: string, repo: string): Promise<number | undefined> => {
  let comments;
  let page = 0;
  let perPage = 100;
  do {
    const response = await octokit.issues.listComments({
      issue_number: issueNumber,
      owner,
      repo,
      per_page: perPage,
      page: ++page,
    });
    if (response.status !== 200) {
      console.log(`Failed to fetch comments. Status: ${response.status}`);
      return;
    }

    ({ data: comments } = response);

    for (const comment of comments) {
      if (comment.body?.includes(searchTitle)) {
        console.log(`Matching Comment ID: ${comment.id}`);

        return comment.id;
      }
    }
  } while (comments.length === perPage);

  return;
};

const hasExistingReviewComments = async (owner: string, repo: string): Promise<boolean> => {
  try {
    const response = await octokit.pulls.listReviewComments({
      owner,
      repo,
      pull_number: issueNumber,
    });

    if (response.status !== 200) {
      console.log(`Failed to fetch review comments. Status: ${response.status}`);
      return false;
    }

    const eklineReviewComments = response.data.filter(
      (comment) => comment.body && comment.body.includes('EkLine')
    );

    console.log(`Found ${eklineReviewComments.length} EkLine review comments`);
    return eklineReviewComments.length > 0;
  } catch (error) {
    console.log(`Error checking review comments: ${error}`);
    return false;
  }
};

(async () => {
  if (!issueNumber) {
    console.log('Issue number is not provided.');
    return;
  }

  if (!repositoryOwner || !repository) {
    console.log('Failed to parse owner and repo from git remote url.');
    return;
  }
  const owner = repositoryOwner;
  const repo = repository.replace(`${owner}/`, '');

  const commentId: number | undefined = await getCommentId(owner, repo);

  // Check if issues were found by checking the output file AND existing review comments
  const outputFile = 'ekOutput.jsonl';
  const hasLocalIssues = existsSync(outputFile) && statSync(outputFile).size > 0;
  const hasReviewIssues = await hasExistingReviewComments(owner, repo);
  const hasIssues = hasLocalIssues || hasReviewIssues;

  console.log(
    `Local issues: ${hasLocalIssues}, Review issues: ${hasReviewIssues}, Total issues: ${hasIssues}`
  );

  const jobComment = hasIssues
    ? searchString.replace('<link>', `${eklineAppURL}/job/review/${jobId}`)
    : positiveString;

  if (commentId) {
    console.log(`Updating comment with ID: ${commentId}`);
    await octokit.issues.updateComment({ comment_id: commentId, owner, repo, body: jobComment });
    return;
  }

  await octokit.issues.createComment({ issue_number: issueNumber, owner, repo, body: jobComment });
})();
