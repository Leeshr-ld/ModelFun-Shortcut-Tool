using System;
using System.IO;
using System.Security.Cryptography;
using System.Text;

namespace RoadLevel
{
    public static class RuntimeIntegrity
    {
        public static string Verify(string appDirectory)
        {
            string manifestPath = Path.Combine(appDirectory, "runtime.sha256");
            if (!File.Exists(manifestPath))
                return "runtime.sha256|missing";

            string manifestHash = ComputeSha256(manifestPath);
            if (!String.Equals(manifestHash, RuntimeManifestHash.Sha256, StringComparison.OrdinalIgnoreCase))
                return "runtime.sha256|hash-mismatch";

            string root = Path.GetFullPath(appDirectory).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar)
                + Path.DirectorySeparatorChar;
            foreach (string rawLine in File.ReadAllLines(manifestPath, Encoding.UTF8))
            {
                string line = rawLine.Trim();
                if (line.Length == 0)
                    continue;

                int separator = line.IndexOf("  ", StringComparison.Ordinal);
                if (separator != 64)
                    return "runtime.sha256|invalid-line";

                string expectedHash = line.Substring(0, 64);
                string relativePath = line.Substring(66);
                string fullPath = Path.GetFullPath(Path.Combine(appDirectory, relativePath));
                if (!fullPath.StartsWith(root, StringComparison.OrdinalIgnoreCase))
                    return relativePath + "|outside-app";
                if (!File.Exists(fullPath))
                    return relativePath + "|missing";

                string actualHash = ComputeSha256(fullPath);
                if (!String.Equals(actualHash, expectedHash, StringComparison.OrdinalIgnoreCase))
                    return relativePath + "|hash-mismatch";
            }

            return null;
        }

        private static string ComputeSha256(string path)
        {
            using (SHA256 sha256 = SHA256.Create())
            using (FileStream stream = File.OpenRead(path))
            {
                byte[] hash = sha256.ComputeHash(stream);
                StringBuilder text = new StringBuilder(hash.Length * 2);
                foreach (byte value in hash)
                    text.Append(value.ToString("X2"));
                return text.ToString();
            }
        }
    }
}
