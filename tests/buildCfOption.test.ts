import { buildCfOption, escapeForShell } from '../src/buildCfOption';
import { execSync } from 'child_process';

describe('escapeForShell', () => {
  it('wraps simple filename in single quotes', () => {
    expect(escapeForShell('file.txt')).toBe("'file.txt'");
  });

  it('escapes single quotes in filename', () => {
    expect(escapeForShell("file's name.txt")).toBe("'file'\\''s name.txt'");
  });
});

describe('buildCfOption', () => {
  it('returns empty string for empty input', () => {
    expect(buildCfOption('')).toBe('');
    expect(buildCfOption('   ')).toBe('');
  });

  it('handles simple filename', () => {
    const result = buildCfOption('simple.md');
    expect(result).toBe("-cf 'simple.md'");
  });

  it('handles spaces in filename', () => {
    const result = buildCfOption('file with spaces.png');
    expect(result).toBe("-cf 'file with spaces.png'");
  });

  it('handles parentheses in filename', () => {
    const result = buildCfOption('Picture1 (2) (1).png');
    expect(result).toBe("-cf 'Picture1 (2) (1).png'");
  });

  it('handles single quotes in filename', () => {
    const result = buildCfOption("file's name.png");
    expect(result).toBe("-cf 'file'\\''s name.png'");
  });

  it('handles dollar signs in filename', () => {
    const result = buildCfOption('$HOME.txt');
    expect(result).toBe("-cf '$HOME.txt'");
  });

  it('handles backticks in filename', () => {
    const result = buildCfOption('file`whoami`.txt');
    expect(result).toBe("-cf 'file`whoami`.txt'");
  });

  it('handles backslashes in filename', () => {
    const result = buildCfOption('path\\to\\file.txt');
    expect(result).toBe("-cf 'path\\to\\file.txt'");
  });

  it('strips git pre-quoted filenames', () => {
    const result = buildCfOption('".gitbook/assets/Screenshot (2).png"');
    expect(result).toBe("-cf '.gitbook/assets/Screenshot (2).png'");
  });

  it('handles filenames with non-ASCII characters (NBSP)', () => {
    // \u00A0 is non-breaking space
    const result = buildCfOption('Screenshot\u00A0(2).png');
    expect(result).toBe("-cf 'Screenshot\u00A0(2).png'");
  });

  it('handles multiple files', () => {
    const files = `simple.md
.gitbook/assets/Picture1 (2) (1).png
file's test.md`;
    const result = buildCfOption(files);
    expect(result).toBe("-cf 'simple.md' '.gitbook/assets/Picture1 (2) (1).png' 'file'\\''s test.md'");
  });

  it('skips empty lines', () => {
    const files = `file1.md

file2.md`;
    const result = buildCfOption(files);
    expect(result).toBe("-cf 'file1.md' 'file2.md'");
  });
});

describe('shell safety', () => {
  const evalInShell = (cfOption: string): string => {
    return execSync('eval "echo $CF_OPTION"', {
      shell: '/bin/bash',
      encoding: 'utf-8',
      env: { ...process.env, CF_OPTION: cfOption },
    }).trim();
  };

  it('dollar signs are not expanded', () => {
    const cfOption = buildCfOption('$HOME.txt');
    const result = evalInShell(cfOption);
    expect(result).toContain('$HOME.txt');
    expect(result).not.toMatch(/\/Users\//);
  });

  it('backticks are not executed', () => {
    const cfOption = buildCfOption('file`whoami`.txt');
    const result = evalInShell(cfOption);
    expect(result).toContain('file`whoami`.txt');
  });

  it('parentheses do not cause syntax errors', () => {
    const cfOption = buildCfOption('Picture1 (2) (1).png');
    const result = evalInShell(cfOption);
    expect(result).toContain('Picture1 (2) (1).png');
  });

  it('single quotes in filename work correctly', () => {
    const cfOption = buildCfOption("file's name.png");
    const result = evalInShell(cfOption);
    expect(result).toContain("file's name.png");
  });
});

