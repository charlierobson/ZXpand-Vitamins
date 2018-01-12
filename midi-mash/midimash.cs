using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;

public static class mp
{
    static bool verbose = false;
    static bool forceFourFour = false;

    static void VerboseWriteLine(string s)
    {
        if (verbose) Console.WriteLine(s);
    }

    static void Main(string[] args)
    {
        var switches = args.Where(x => x.StartsWith("-"));
        foreach (var sw in switches)
        {
            switch (sw)
            {
                case "-v":
                case "-V":
                    verbose = true;
                    break;
                case "-4":
                    forceFourFour = true;
                    break;
            }

        }
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
                },{
                    "Header", null
                },{
                    "Tempo", null
                },{
                    "Time_signature", null
                }
            };

            var midi = new SortedDictionary<int, List<byte>>();

            var lines = File.ReadAllLines(args[0]);

            var header = lines.FirstOrDefault(l => l.Contains("Header"));
            if (header == null) throw new Exception("No Header information found, unable to determine playback rate.");

            var tempo = lines.FirstOrDefault(l => l.Contains("Tempo"));
            if (tempo == null) throw new Exception("No Tempo information found, unable to determine playback rate.");

            var timeSig = lines.FirstOrDefault(l => l.Contains("Time_signature"));
            if (timeSig == null) throw new Exception("No time signature information found, unable to determine playback rate.");

            var headerParts = header.Split(',').Select(p => p.Trim()).ToArray();
            var tempoParts = tempo.Split(',').Select(p => p.Trim()).ToArray();
            var timeSigParts = timeSig.Split(',').Select(p => p.Trim()).ToArray();
            /*
            0, 0, Header, 0, 1, 192
            1, 0, Time_signature, 2, 2, 24, 8
            1, 0, Tempo, 387096
             */
            var ticksPerQuarterNote = int.Parse(headerParts[5]);

            const double oneMinuteInMicroseconds = 60000000;
            var microsecondsPerQuarterNote = int.Parse(tempoParts[3]);

            var timeSignatureNumerator = int.Parse(timeSigParts[3]);
            var timeSignatureDenominator = Math.Pow(2, int.Parse(timeSigParts[4]));
            if (forceFourFour)
            {
                timeSignatureNumerator = 4;
                timeSignatureDenominator = 4;
            }

            var bpm = Math.Round(oneMinuteInMicroseconds / microsecondsPerQuarterNote * (timeSignatureDenominator / timeSignatureNumerator));

            var secondsPerQuarterNote = microsecondsPerQuarterNote / 1000000.0f;
            var secondsPerTick = secondsPerQuarterNote / ticksPerQuarterNote;
            var fiftiethsPerTick = secondsPerTick * 50;

            Console.WriteLine($"BPM: {bpm}");
            Console.WriteLine($"Time signature: {timeSignatureNumerator}/{timeSignatureDenominator}");

            var biggestBlock = 0;
            var lastTick = 0;

            foreach (var line in lines)
            {
                var components = line.Split(',').Select(p => p.Trim()).ToArray();
                if (msgMap.Keys.Contains(components[2]))
                {
                    if (msgMap[components[2]] == null) continue;

                    var msg = msgMap[components[2]](components);

                    lastTick = int.Parse(components[1]);

                    var deltaTimeInFiftieths = (int)(lastTick * fiftiethsPerTick);
                    if (!midi.ContainsKey(deltaTimeInFiftieths))
                    {
                        midi[deltaTimeInFiftieths] = new List<byte>();
                    }

                    var midiData = midi[deltaTimeInFiftieths];

                    midiData.AddRange(msg);

                    biggestBlock = Math.Max(biggestBlock, midiData.Count);
                }
                else
                {
                    VerboseWriteLine($"Unknown event type: {components[2]}");
                }
            }

            var lastMinutes = Math.Floor(lastTick * secondsPerTick / 60);
            var lastSeconds = (lastTick * secondsPerTick) - (60 * lastMinutes);

            Console.WriteLine($"Duration: {lastMinutes}:{lastSeconds}");

            const int blockSize = 256;
            const int headerByteCount = 4;

            //var minBlockSize = (int)(Math.Pow(2, Math.Ceiling(Math.Log(biggestBlock + HeaderByteCount)/Math.Log(2))));
            //Console.WriteLine($"Block size is {minBlockSize} bytes.");

            if (lastTick >= Math.Pow(2, 24))
                Console.WriteLine("Error: time stamp cannot be represented by 24 bit value.");

            if (biggestBlock > blockSize - headerByteCount)
            {
                Console.WriteLine("Error: block size exceeds maximum.");
            }
            else
            {
                var rawFile = new List<byte>();
                foreach (var key in midi.Keys)
                {
                    // header = frame number @ 24 bits, midi packet size in bytes @ 8 bits
                    rawFile.Add((byte)((key & 0x0000ff)));
                    rawFile.Add((byte)((key & 0x00ff00) >> 8));
                    rawFile.Add((byte)((key & 0xff0000) >> 16));
                    rawFile.Add((byte)(midi[key].Count));

                    rawFile.AddRange(midi[key]);

                    var blkRemain = blockSize - headerByteCount - midi[key].Count;
                    rawFile.AddRange(new byte[blkRemain]);
                }

                File.WriteAllBytes(Path.ChangeExtension(args[0], ".zxm"), rawFile.ToArray());
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine(ex.ToString());
        }
    }
}
