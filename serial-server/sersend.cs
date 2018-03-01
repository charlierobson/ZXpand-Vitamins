using System;
using System.IO;
using System.IO.Ports;

class Program
{
    private static void Main(string[] args)
    {
        if (args.Length < 2)
        {
            Console.WriteLine("Invalid arguments. Specify file and serial device name.");
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

            var pOffset = 0;
            var pRemaining = pBytes.Length;

            while(pRemaining != 0)
            {
                var blockSize = pRemaining < 128 ? pRemaining : 128;

                Console.WriteLine("Block size " + blockSize);
                serial.Write(new[] { (byte)0x81, (byte)blockSize }, 0, 2);

                var response = serial.ReadByte();
                if (response == 0xB0)
                {
                    Console.Write("Send block..");
                    serial.Write(pBytes, pOffset, blockSize);
                    Console.WriteLine(" OK");
                }

                pOffset += blockSize;
                pRemaining -= blockSize;
            }

            Console.WriteLine("Signing off");
            serial.Write(new[] { (byte)0x81, (byte)0 }, 0, 2);
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Exception: {ex.Message}");
        }
    }
}
