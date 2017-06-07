using System;
using System.IO;
using System.IO.Ports;

class Program
{
    private static void Main(string[] args)
    {
        if (args.Length < 2)
        {
            Console.WriteLine("Invalid arguments. Specify P file and serial device name.");
            return;
        }

        try
        {
            var pBytes = File.ReadAllBytes(args[0]);
            Console.WriteLine($"{pBytes.Length} bytes read.");

            var serialPortString = args[1];
            var serial = new SerialPort(serialPortString, 38400) {ReadTimeout = 400};

            serial.Open();
            serial.DiscardInBuffer();
            serial.DiscardOutBuffer();

            Console.WriteLine($"Using serial port '{serialPortString}' 38400,8,N,1");

            Console.WriteLine("Server running.");

            byte b = default(byte);

            do
            {
                try
                {
                    b = (byte) serial.ReadByte();
                    Console.Write($"\n {(char)b} ");

                    if (b == 'I')
                    {
                        // client requests info block {len:2}
                        Console.Write($" -> {pBytes.Length}");

                        serial.Write(new[] { (byte)(pBytes.Length & 0xff), (byte)(pBytes.Length >> 8) }, 0, 2);
                    }
                    else if (b == 'T')
                    {
                        // client requests transmission of block X
                        var blockNum = serial.ReadByte();
                        var blockLen = serial.ReadByte();
                        if (blockLen == 0) blockLen = 256;

                        Console.Write($" {blockNum,3}, {blockLen,3} -> ");

                        SendBlock(serial, pBytes, blockNum*256, blockLen);
                    }
                    else if (b == 'X')
                    {
                        Console.WriteLine($" -> OK!");
                    }
                    else
                    {
                        Console.Write(" ?");
                    }
                }
                catch (TimeoutException)
                {
                }
            }
            while (b != 'X');
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Exception: {ex.Message}");
        }
    }

    private static void SendBlock(SerialPort serial, byte[] pBytes, int offset, int blockSize)
    {
        var sum = 0;

        for (var i = 0; i < blockSize; ++i)
        {
            var b = pBytes[offset + i];
            serial.Write(pBytes, offset + i, 1);
            sum += b;
        }

        serial.Write(new byte[]{ (byte)(sum & 0xff), (byte)((sum >> 8) & 0xff) }, 0, 2);

        Console.Write($" ${sum:X4}");
    }
}
