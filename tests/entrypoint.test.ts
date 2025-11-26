import { execSync, ExecSyncOptionsWithStringEncoding } from 'child_process';
import * as path from 'path';

const ENTRYPOINT_PATH = path.resolve(__dirname, '../entrypoint.sh');

const execOptions: ExecSyncOptionsWithStringEncoding = {
  shell: '/bin/bash',
  encoding: 'utf-8',
  env: { ...process.env, SOURCED_FOR_TEST: 'true' },
};

const sourceAndRun = (command: string, env: Record<string, string> = {}): string => {
  const fullCommand = `source '${ENTRYPOINT_PATH}' && ${command}`;
  return execSync(fullCommand, { ...execOptions, env: { ...execOptions.env, ...env } }).trim();
};

describe('entrypoint.sh', () => {
  describe('print_debug_info', () => {
    it('prints INPUT_ variables when INPUT_DEBUG is true', () => {
      const result = sourceAndRun('print_debug_info', {
        INPUT_DEBUG: 'true',
        INPUT_TEST_VAR: 'test_value',
      });

      expect(result).toContain('Debug Mode: Printing all INPUT_ variables');
      expect(result).toContain('INPUT_TEST_VAR=test_value');
    });

    it('prints nothing when INPUT_DEBUG is false', () => {
      const result = sourceAndRun('print_debug_info', { INPUT_DEBUG: 'false' });
      expect(result).toBe('');
    });
  });

  describe('setGithubPullRequestId', () => {
    it('extracts PR ID from refs/pull/123/merge', () => {
      const result = sourceAndRun(
        'setGithubPullRequestId && echo "$pull_request_id"',
        { GITHUB_REF: 'refs/pull/123/merge' }
      );
      expect(result).toBe('123');
    });

    it('returns empty for non-pull refs', () => {
      const result = sourceAndRun(
        'setGithubPullRequestId && echo "$pull_request_id"',
        { GITHUB_REF: 'refs/heads/main' }
      );
      expect(result).toBe('');
    });
  });
});
