# **Lifebloom Glow**

Options: **/lbg**

![glows](https://i.imgur.com/zsX0tUM.png "glows")

TL;DR This is an extremely lightweight addon that puts a glow around lifebloom's icon when it is in the pandemic window.

The "pandemic window" is the window of time in which you can recast a hot or dot and have the rest of the damage or healing "roll over" into the new hot/dot.  Note that the pandemic window changes based on the initial duration of the buff, and buff duration also changes based on if you've refreshed it in the pandemic window or not (this increase in duration is part of the "roll over" effect).

When you refresh lifebloom in this window of time, there is a secondary effect that happens: The "bloom" that normally only happens when you let it expire or it gets dispelled gets triggered.

Because of this, it is recommended to always refresh lifebloom in this important window of time. However, there is no official way to tell when exactly this window is available.

This addon was meant to eliminate the guesswork involved with knowing when to refresh Lifebloom by putting a glow border (the same border that is used for dispellable/stealable buffs) around lifebloom when it is in the correct pandemic window.


**Notes**

- Only Blizzard frames are currently supported (Raid Frames, TargetFrame, FocusFrame)
- Easily editable OnUpdate throttle value in LifebloomGlow.lua for the CPU conscious (see comments in the file).

**Contribution**

- [Report bugs](https://www.curseforge.com/wow/addons/lifebloom-glow/issues "Report bugs")
- [Source code](https://github.com/clicketz/lifebloom-glow "Source code")
