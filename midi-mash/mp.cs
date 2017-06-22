using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;

public static class mp
{
    static bool verbose = true;

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

            var tempo = lines.FirstOrDefault(l => l.Contains("Tempo"));
            var tempoParts = tempo.Split(',').Select(p => p.Trim()).ToArray();
            var microsecondsPerQuarterNote = int.Parse(tempoParts[3]);

            var timeSig = lines.FirstOrDefault(l => l.Contains("Time_signature"));
            var timeSigParts = timeSig.Split(',').Select(p => p.Trim()).ToArray();

            var oneMinuteInMicroseconds = 60000000;
            var timeSignatureNumerator = int.Parse(timeSigParts[3]);
            var timeSignatureDenominator = Math.Pow(2, int.Parse(timeSigParts[4]));
            var ticksPerQuarterNote = int.Parse(timeSigParts[5]);
    
            var bpm = (oneMinuteInMicroseconds / microsecondsPerQuarterNote) * (timeSignatureDenominator / timeSignatureNumerator);
            Console.WriteLine($"BPM: {bpm}");

            var secondsPerQuarterNote = microsecondsPerQuarterNote / 1000000.0f;
            var secondsPerTick = secondsPerQuarterNote / ticksPerQuarterNote;
            var fiftiethsPerTick = secondsPerTick * 50;

            foreach(var line in lines)
            {
                var components = line.Split(',').Select(p => p.Trim()).ToArray();
                if (msgMap.Keys.Contains(components[2]))
                {
                    var deltaTimeInFiftieths = (int)(int.Parse(components[1]) * fiftiethsPerTick);
                    VerboseWriteLine(deltaTimeInFiftieths.ToString());
                    if (!midi.ContainsKey(deltaTimeInFiftieths))
                    {
                        midi[deltaTimeInFiftieths] = new List<byte>();
                    }

                    var midiData = midi[deltaTimeInFiftieths];
                    midiData.AddRange(msgMap[components[2]](components));
                }
                else
                {
                    VerboseWriteLine($"Unknown event type: {components[2]}");
                }
            }

            VerboseWriteLine($"Seconds per tick: {secondsPerTick}");

            int biggestKey = 0;
            int biggestBlock = 0;

            foreach(var key in midi.Keys)
            {
                var data = midi[key];
                if (data.Count > biggestBlock)
                {
                    biggestBlock = data.Count;
                    biggestKey = key;
                }
            }

            VerboseWriteLine($"Block count: {midi.Count}");
            VerboseWriteLine($"Biggest block ({biggestKey}) contains {biggestBlock} bytes.");

            var rawFile = new List<byte>();
            foreach(var key in midi.Keys)
            {
                rawFile.Add((byte)(key & 255));
                rawFile.Add((byte)(key / 256));
                rawFile.Add((byte)(midi[key].Count));

                rawFile.AddRange(midi[key]);

                var blkRemain = 128 - midi[key].Count - 3;
                rawFile.AddRange(new byte[blkRemain]);
            }

            File.WriteAllBytes(Path.ChangeExtension(args[0], ".zxm"), rawFile.ToArray());
        }
        catch(Exception ex)
        {
            Console.WriteLine(ex.ToString());
        }
    }
}