using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;

public static class mp
{
    static bool verbose = false;

    static void VerboseWriteLine(string s)
    {
        if (verbose) Console.WriteLine(s);
    }

    static void Main(string[] args)
    {
        try
        {
            var msgMap = new Dictionary<string, Func<string[], byte[]>>
            {
                { "Note_off_c", s => {
                        var channel = Byte.Parse(s[3]);
                        var note = Byte.Parse(s[4]);
                        var velocity = Byte.Parse(s[5]);
                        return new byte[]{(byte)(0x80|channel),note,velocity};
                    }
                },{ "Note_on_c", s => {
                        var channel = Byte.Parse(s[3]);
                        var note = Byte.Parse(s[4]);
                        var velocity = Byte.Parse(s[5]);
                        return new byte[]{(byte)(0x90|channel),note,velocity};
                    }
                },{ "Control_c", s => {
                        var channel = Byte.Parse(s[3]);
                        var controller = Byte.Parse(s[4]);
                        var value = Byte.Parse(s[5]);
                        return new byte[]{(byte)(0xb0|channel),controller,value};
                    }
                },{ "Program_c",s => {
                        var channel = Byte.Parse(s[3]);
                        var patch = Byte.Parse(s[4]);
                        return new byte[]{(byte)(0xc0|channel),patch};
                    }
                },{ "Pitch_bend_c", s => {
                        var channel = Byte.Parse(s[3]);
                        var bend = UInt16.Parse(s[4]);
                        return new byte[]{(byte)(0xe0|channel),(byte)(bend & 127), (byte)(bend / 128)};
                    }
                }
            };

            var midi = new SortedDictionary<int, List<byte>>();

            var lines = File.ReadAllLines(args[0]);

            var header = lines.FirstOrDefault(l => l.Contains("Header"));
            var headerParts = header.Split(',').Select(p => p.Trim()).ToArray();
            var ticksPerQuarterNote = int.Parse(headerParts[5]);

            var tempo = lines.FirstOrDefault(l => l.Contains("Tempo"));
            var tempoParts = tempo.Split(',').Select(p => p.Trim()).ToArray();
            var microsecondsPerQuarterNote = int.Parse(tempoParts[3]);

            var timeSig = lines.FirstOrDefault(l => l.Contains("Time_signature"));
            var timeSigParts = timeSig.Split(',').Select(p => p.Trim()).ToArray();

            var oneMinuteInMicroseconds = 60000000;
            var timeSignatureNumerator = int.Parse(timeSigParts[3]);
            var timeSignatureDenominator = Math.Pow(2, int.Parse(timeSigParts[4]));

            var bpm = (oneMinuteInMicroseconds / microsecondsPerQuarterNote) * (timeSignatureDenominator / timeSignatureNumerator);
            VerboseWriteLine($"BPM: {bpm}");

            var secondsPerQuarterNote = microsecondsPerQuarterNote / 1000000.0f;
            var secondsPerTick = secondsPerQuarterNote / ticksPerQuarterNote;
            var fiftiethsPerTick = secondsPerTick * 50;

            var biggestBlock = 0;
            var lastTimeStamp = 0;

            foreach(var line in lines)
            {
                var components = line.Split(',').Select(p => p.Trim()).ToArray();
                if (msgMap.Keys.Contains(components[2]))
                {
                    var msg = msgMap[components[2]](components);

                    var deltaTimeInFiftieths = (int)(int.Parse(components[1]) * fiftiethsPerTick);
                    if (!midi.ContainsKey(deltaTimeInFiftieths))
                    {
                        midi[deltaTimeInFiftieths] = new List<byte>();
                    }

                    var midiData = midi[deltaTimeInFiftieths];

                    midiData.AddRange(msg);

                    biggestBlock = Math.Max(biggestBlock, midiData.Count);
                    lastTimeStamp = deltaTimeInFiftieths;
                }
                else
                {
                    VerboseWriteLine($"Unknown event type: {components[2]}");
                }
            }

            const int blockSize = 256;
            const int HeaderByteCount = 4;

            //var minBlockSize = (int)(Math.Pow(2, Math.Ceiling(Math.Log(biggestBlock + HeaderByteCount)/Math.Log(2))));
            //Console.WriteLine($"Block size is {minBlockSize} bytes.");

            if (lastTimeStamp >= Math.Pow(2,24))
                Console.WriteLine("Error: time stamp cannot be represented by 24 bit value.");

            if (biggestBlock > blockSize - HeaderByteCount)
            {
                Console.WriteLine("Error: block size exceeds maximum.");
            }
            else
            {
                var rawFile = new List<byte>();
                foreach(var key in midi.Keys)
                {
                    // header = frame number @ 24 bits, midi packet size in bytes @ 8 bits
                    rawFile.Add((byte)((key & 0x0000ff)));
                    rawFile.Add((byte)((key & 0x00ff00) >> 8));
                    rawFile.Add((byte)((key & 0xff0000) >> 16));
                    rawFile.Add((byte)(midi[key].Count));

                    rawFile.AddRange(midi[key]);

                    var blkRemain = blockSize - HeaderByteCount - midi[key].Count;
                    rawFile.AddRange(new byte[blkRemain]);
                }

                File.WriteAllBytes(Path.ChangeExtension(args[0], ".zxm"), rawFile.ToArray());
            }
        }
        catch(Exception ex)
        {
            Console.WriteLine(ex.ToString());
        }
    }
}
