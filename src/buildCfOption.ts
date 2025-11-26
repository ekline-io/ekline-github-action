export const escapeForShell = (filename: string): string => {
  // Single quotes in shell don't interpret $, `, or \ specially
  // To include a single quote, we end the string, add escaped quote, restart: 'file'\''s name'
  return `'${filename.replace(/'/g, "'\\''")}'`;
};

const stripGitQuotes = (filename: string): string => {
  if (!filename.startsWith('"') || !filename.endsWith('"')) {
    return filename;
  }

  // Remove outer quotes first
  let content = filename.slice(1, -1);

  // Helper to replace escape sequences
  // Matches:
  // 1. Octal: \000 to \377 (1-3 digits)
  // 2. Unicode: \uXXXX (4 hex digits)
  // 3. Control chars: \a, \b, \t, etc.
  // 4. Literal escapes: \\, \"
  return content.replace(/\\([0-7]{1,3}|u[0-9a-fA-F]{4}|[abfnrtv"\\?])/g, (match, code) => {
    // Handle Octal \nnn
    if (/^[0-7]+$/.test(code)) {
      return String.fromCharCode(parseInt(code, 8));
    }
    
    // Handle Unicode \uXXXX
    if (code.startsWith('u')) {
      return String.fromCharCode(parseInt(code.slice(1), 16));
    }

    // Handle C-style escapes
    const escapes: Record<string, string> = {
      'a': '\x07',
      'b': '\b',
      'f': '\f',
      'n': '\n',
      'r': '\r',
      't': '\t',
      'v': '\v',
      '"': '"',
      '\\': '\\',
      '?': '?'
    };

    return escapes[code] || match;
  });
};

export const buildCfOption = (changedFiles: string): string => {
  if (!changedFiles.trim()) {
    return '';
  }

  const files = changedFiles
    .split('\n')
    .map(f => f.trim())
    .filter(f => f.length > 0)
    .map(stripGitQuotes)
    .map(escapeForShell);

  return `-cf ${files.join(' ')}`;
};

const main = (): void => {
  try {
    const changedFiles = process.argv[2] || '';
    const result = buildCfOption(changedFiles);
    process.stdout.write(result);
  } catch (error) {
    console.error('Error building cf option:', error);
    process.exit(1);
  }
};

if (require.main === module) {
  main();
}
