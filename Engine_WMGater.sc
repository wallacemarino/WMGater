Engine_WMGater : CroneEngine {
    var <synth;

    *new { arg context, doneCallback;
        ^super.new(context, doneCallback);
    }

    alloc {
        SynthDef(\wmGater, {
            arg out=0, gate=0, level=1.0,
            attack=0.01, decay=0.1, sustain=0.5, release=0.01,
            wobbleRate=0.5, wobbleDepth=0.5, wobbleMix=0.0,
            delayMode=0, delaytime=0.2, delayfeedback=0.3, delaymix=0.0;
            
            var sig, env, dry, wobbleVoice1, wobbleVoice2, wobbleOut, wet;
            
            // Input stage with protection
            sig = SoundIn.ar([0,1], 0.8);
            sig = Limiter.ar(sig, 0.95);
            
            // ADSR envelope
            env = EnvGen.kr(
                Env.adsr(
                    attackTime: attack,
                    decayTime: decay,
                    sustainLevel: sustain,
                    releaseTime: release,
                    curve: [-4, -4, -4, -4]
                ),
                gate: gate,
                levelScale: level,
                doneAction: 0
            );
            
            dry = sig * env;

            // Wobbler section
            wobbleVoice1 = DelayC.ar(
                dry,
                0.080,
                SinOsc.kr(
                    wobbleRate,
                    mul: wobbleDepth * 0.03,
                    add: 0.02
                )
            );

            wobbleVoice2 = DelayC.ar(
                dry,
                0.080,
                SinOsc.kr(
                    wobbleRate * 0.94,
                    mul: wobbleDepth * 0.025,
                    add: 0.025
                )
            );

            wobbleOut = Mix([
                Pan2.ar(wobbleVoice1, -0.6),
                Pan2.ar(wobbleVoice2, 0.6)
            ]) * 0.5;

            dry = XFade2.ar(dry, wobbleOut, wobbleMix * 2 - 1);
            
            // Delay section
            wet = Select.ar(delayMode,
                [
                    // Mono mode
                    DelayC.ar(
                        dry + (LocalIn.ar(2) * delayfeedback),
                        2.0,
                        delaytime
                    ),
                    // Ping-pong mode
                    DelayC.ar(
                        [
                            dry[0] + (LocalIn.ar(2)[1] * delayfeedback),
                            dry[1] + (LocalIn.ar(2)[0] * delayfeedback)
                        ],
                        2.0,
                        [delaytime, delaytime * 1.5]
                    )
                ]
            );
            
            LocalOut.ar(wet);
            
            // Final mix with proper attenuation
            sig = (dry * (1 - delaymix)) + (wet * delaymix);
            sig = Limiter.ar(sig, 0.95);
            
            Out.ar(out, sig);
        }).add;

        context.server.sync;

        synth = Synth.new(\wmGater, [
            \out, context.out_b.index,
            \gate, 0,
            \level, 1.0,
            \attack, 0.01,
            \decay, 0.1,
            \sustain, 0.5,
            \release, 0.01,
            \wobbleRate, 0.5,
            \wobbleDepth, 0.5,
            \wobbleMix, 0.0,
            \delayMode, 0,
            \delaytime, 0.2,
            \delayfeedback, 0.3,
            \delaymix, 0.0
        ], context.xg);

        this.addCommand("gate", "f", { arg msg; synth.set(\gate, msg[1]); });
        this.addCommand("level", "f", { arg msg; synth.set(\level, msg[1]); });
        this.addCommand("attack", "f", { arg msg; synth.set(\attack, msg[1]); });
        this.addCommand("decay", "f", { arg msg; synth.set(\decay, msg[1]); });
        this.addCommand("sustain", "f", { arg msg; synth.set(\sustain, msg[1]); });
        this.addCommand("release", "f", { arg msg; synth.set(\release, msg[1]); });
        this.addCommand("wobbleRate", "f", { arg msg; synth.set(\wobbleRate, msg[1]); });
        this.addCommand("wobbleDepth", "f", { arg msg; synth.set(\wobbleDepth, msg[1]); });
        this.addCommand("wobbleMix", "f", { arg msg; synth.set(\wobbleMix, msg[1]); });
        this.addCommand("delayMode", "f", { arg msg; synth.set(\delayMode, msg[1]); });
        this.addCommand("delaytime", "f", { arg msg; synth.set(\delaytime, msg[1]); });
        this.addCommand("delayfeedback", "f", { arg msg; synth.set(\delayfeedback, msg[1]); });
        this.addCommand("delaymix", "f", { arg msg; synth.set(\delaymix, msg[1]); });
    }

    free {
        synth.free;
    }
}
