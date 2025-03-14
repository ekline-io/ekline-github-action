/**
 * Date utility functions for the GitHub Action
 */

/**
 * Calculates a date X months ago from the current date
 * @param monthsAgo - Number of months to go back
 * @returns Date in YYYY-MM-DD format (first day of the month)
 */
export const getDateMonthsAgo = (monthsAgo: number): string => {
  const date = new Date();
  date.setMonth(date.getMonth() - monthsAgo);
  const year = date.getFullYear();

  // Format month with leading zero if needed
  const month = (date.getMonth() + 1).toString().padStart(2, '0');

  return `${year}-${month}-01`;
};

/**
 * Parses command line arguments and returns the months ago value
 * @param args - Command line arguments
 * @returns The number of months ago
 */
const parseArgs = (args: string[]): number => {
  const monthsArg = args[2];

  if (!monthsArg) {
    console.error('Usage: node dateUtils.js <months_ago>');
    process.exit(1);
  }

  const monthsAgo = parseInt(monthsArg, 10);
  if (isNaN(monthsAgo)) {
    console.error('Error: months_ago must be a number');
    process.exit(1);
  }

  return monthsAgo;
};

/**
 * Main function that runs when this file is executed directly
 */
const main = async (): Promise<void> => {
  const monthsAgo = parseArgs(process.argv);
  console.log(getDateMonthsAgo(monthsAgo));
};

// Execute main function
main().catch((error) => {
  console.error('Error:', error);
  process.exit(1);
});
