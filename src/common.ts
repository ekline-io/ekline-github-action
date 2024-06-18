import { exec } from 'child_process';

const asyncExec = (cmd: string): Promise<string> => new Promise((resolve, reject) => {
    exec(cmd, (error, stdout, stderr) => {
        if (error) {
            return reject(error);
        } else if(stderr){
            return reject(stderr);
        }
        resolve(stdout);
    });
});

export const executeCommandSafely = async (cmd: string): Promise<string> => {
    try {
      const stdout = await asyncExec(cmd);
      return stdout || '';
    } catch (error) {
      console.log(error, `Failed to execute command: ${cmd}.`);
      return '';
    }
  };
