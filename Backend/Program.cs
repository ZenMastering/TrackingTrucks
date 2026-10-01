using Microsoft.Data.Sqlite;
using LibGit2Sharp;

namespace Backend
{
    internal class Program
    {
        static string connectionString = "Data Source=app.db";

        static void Main(string[] args)
        {
            Database.clearFolder();
            Database.pullGitDatabase();
        }
    }
}