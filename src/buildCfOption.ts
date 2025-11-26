export const escapeForShell = (filename: string): string => {
  // Single quotes in shell don't interpret $, `, or \ specially
  // To include a single quote, we end the string, add escaped quote, restart: 'file'\''s name'
  return `'${filename.replace(/'/g, "'\\''")}'`;
};

const stripGitQuotes = (filename: string): string => {
  // Git may pre-quote filenames with special characters: "path/to/file.png"
  if (filename.startsWith('"') && filename.endsWith('"')) {
    return filename.slice(1, -1);
  }
  return filename;
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

