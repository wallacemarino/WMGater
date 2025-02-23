Engine_WMGater : CroneEngine {
    var <synth;

    *new { arg context, doneCallback;
        ^super.new(context, doneCallback);
    }

    alloc {
        SynthDef(\wmGater, {
            arg out=0, gate=0, level=1.0, attack=0.01, release=0.01,
            delaytime=0.2, delayfeedback=0.3, delaymix=0.0;
            
            var sig, env, dry, wet;
            
            // Input stage matching hardware spec [[1]](https://poe.com/citation?message_id=350125587729&citation=1)
            sig = SoundIn.ar([0,1], 0.8);
            
            env = EnvGen.kr(
                Env.asr(attack, 1, release, [-4, 4]),
                gate,
                doneAction: 0
            );
            
            dry = sig * env * level;
            
            // Simplified delay network to prevent initialization issues
            wet = DelayN.ar(
                in: (dry + (LocalIn.ar(2) * delayfeedback)),
                maxdelaytime: 2.0,
                delaytime: delaytime.clip(0.02, 2.0)
            );
            
            LocalOut.ar(wet);
            
            // Basic mixing to ensure stable initialization
            sig = (dry * (1 - delaymix)) + (wet * delaymix);
            
            // Protection against hardware constraints [[1]](https://poe.com/citation?message_id=350125587729&citation=1)
            sig = LeakDC.ar(sig);
            sig = Limiter.ar(sig, 0.95);
            
            Out.ar(out, sig);
        }).add;

        context.server.sync;

        synth = Synth.new(\wmGater, [
            \out, 0,
            \gate, 0,
            \level, 1.0,
            \attack, 0.01,
            \release, 0.01,
            \delaytime, 0.2,
            \delayfeedback, 0.3,
            \delaymix, 0.0
        ], context.xg);

        this.addCommand("gate", "f", { arg msg;
            synth.set(\gate, msg[1]);
        });

        this.addCommand("level", "f", { arg msg;
            synth.set(\level, msg[1]);
        });

        this.addCommand("attack", "f", { arg msg;
            synth.set(\attack, msg[1]);
        });

        this.addCommand("release", "f", { arg msg;
            synth.set(\release, msg[1]);
        });

        this.addCommand("delaytime", "f", { arg msg;
            synth.set(\delaytime, msg[1]);
        });

        this.addCommand("delayfeedback", "f", { arg msg;
            synth.set(\delayfeedback, msg[1]);
        });

        this.addCommand("delaymix", "f", { arg msg;
            synth.set(\delaymix, msg[1]);
        });
    }

    free {
        synth.free;
    }
}