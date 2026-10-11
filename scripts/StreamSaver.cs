using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;

public static class StreamSaver {
    public static void SaveToFile(object comStream, string path) {
        IStream stream = (IStream)comStream;
        using (FileStream fs = File.Create(path)) {
            byte[] buffer = new byte[65536];
            IntPtr pRead = Marshal.AllocHGlobal(4);
            try {
                while (true) {
                    stream.Read(buffer, buffer.Length, pRead);
                    int read = Marshal.ReadInt32(pRead);
                    if (read <= 0) break;
                    fs.Write(buffer, 0, read);
                }
            } finally {
                Marshal.FreeHGlobal(pRead);
            }
        }
    }
}
