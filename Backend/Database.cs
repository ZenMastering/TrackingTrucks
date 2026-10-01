using LibGit2Sharp;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Backend
{
    public class Database
    {
        static Dictionary<string, string> databaseVars = new Dictionary<string, string>();

        public static void clearFolder()
        {
            if (Directory.Exists("localRepoCopy"))
            {
                DirectoryInfo di = new DirectoryInfo("localRepoCopy");

                // Delete all files
                foreach (FileInfo file in di.EnumerateFiles())
                {
                    file.Delete();
                }
                di = new DirectoryInfo("localRepoCopy");
                // Delete all subdirectories recursively
                foreach (DirectoryInfo dir in di.EnumerateDirectories())
                {
                    Directory.Delete(dir.FullName); // 'true' enables recursive deletion of contents
                }
            }
        }
        public static void pullGitDatabase()
        {
            string repoUrl = "https://github.com/ZenMastering/TrackingTrucks.git";
            string localPath = "localRepoCopy";
            string targetBranch = "octowalrus/Scrum-206";
            var cloneOptions = new CloneOptions
            {
                BranchName = targetBranch
            };
            try
            {
                // Clone the specific branch
                Repository.Clone(repoUrl, localPath, cloneOptions);
                Console.WriteLine($"Repository cloned successfully on branch '{targetBranch}'!");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error cloning repository: {ex.Message}");
            }
        }
    }
}
