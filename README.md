# OledCare
An Autohotkey script to help the longevity of oled screens

How does this help? first you need to make sure you understand why does burn in happen, no worries I will give you the short version,
- Oled screens work by using organic leds to light up each individual pixel (but you already knew that),
- However contrary to common misconceptions the Oleds do not produce color by themselves they still use a color filter as most common screens.

In ELI5 form:
 - The oled themselves are basically microscopic flashlights and each one lights one pixel.
The more you use each flashlight the more it's battery will drain (i.e. will lose its ability to produce light),
the brighter you turn each flashlight obviously will make it drain even faster.

So:
- Burn becomes visible when some of these tiny flashlights do not shine as bight as the others.
Manufacturers have added pixel refresh and other things that basically force the flashlights 
that are still good to drain (degrade) so they match the ones that are worn, not cool right? but this makes burn in invisible, at the cost of overall
brightness, there is more to it and reasons why you want to keep that on, but to keep this brief, just trust me on that.

This Script attempts to mitigate that wear by turning down the brightness of the most common offender:
The windows taskbar and start icon.

This is achieved by placing transparent rectangle on top of the icons which effectively dims them, letting the battery of our tiny flashlights last longer and
hopefully match the wear on the rest of the screen, hopefully the pixel refresh not grind down so hard to keep all at the same wear level.

What makes this different from a black screen saver you ask?

It will only do so on the oled screen so regular screens that do not need to be babied are not affected, if you put a transparency like
the one this script does it just shows black on those, since their contrast is so low.

Additionally, after a few minutes it will place the transparent rectangle all over the screen if you have been inactive, and after a few more minutes it will
put the monitor into a sleep/standby state, this helps because:

1. It will only affect the Oled monitor
2. I will make the monitor stop counting usage hours when all the pixels are off (black screen saver still registers as monitor usage because of, reasons)
3. Will come back a second after you move your mouse or keyboard.
4. I Won't flash your screen as some screensavers do when activating
5. I Won't be stopped by other apps that cause the screen saver not to trigger.

