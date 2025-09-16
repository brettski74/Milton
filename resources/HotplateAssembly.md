# Hotplate Assembly

## Disclaimer

This is just one way to potentially mount a solder reflow hotplate and is the way that I have
done it. I believe this provdes a relatively safe and reliable mounting solution. Note that
there is no guarantee that my approach is without risk. It is possible that I've overlooked
something. I don't claim to be an expert. Ultimately, this is a device that is intentionally
designed to get very hot and has the potential to cause injury and fire. If you think you have
a better way to do this, I'd love to hear about it and I'll be happy to incorporate
improvements or alternatives where they make sense. In any case, if you build one of these,
you do so at your own risk. I strongly recommend that you disconnect your hotplate from power
at any time that it is not in use and not under direct supervision so that if anything does
go wrong, someone is there to take action before it becomes a major catastrophe.

## Tools and Materials Needed

To assemble your hotplate you'll need the following items:

* 1 Hotplate PCB, setup with thermal fuse and power connections installed
* 1 [Hotplate Base](#hotplate-base)
* 6 M3 x 25mm cap screws
* 12 15mm M3 fender washers
* 10 M3 belleville washers
* 10 7/8/9mm M3 flat washers
* 6 M3 nuts
* 4 M3 x 20mm metal standoffs (stainless steel or brass)
* 4 M3 x 8mm machine screws
* 4 extra 7/8/9mm M3 flat washers (only required if using non-flat head screws such as pan head or truss head machine screws)
* high temperature insulation (eg. glassfibre tube, etc)
* 2 power leads with M3 ring terminals, 30-40cm in length, 14AWG stranded wire or equivalent, silicone insulation preferred

Tools:

* Screwdrivers (which head depends on the screws you buy)
* Pliers
* 5.5mm spanner (wrench)
* 3/16" spanner (wrench) - optional

## Assembly

### 1. Secure each of the 6 cap screws in the base

Using 2 fender washers, 1 belleville washer and 1 M3 nut, secure each of the 6 cap screws in the
base as shown. The screw terminals should be firmly tightened with a spanner. The 4 cap screws
for the mounting legs should be done up finger tight only.

### 2. Add a second M3 nut onto the 4 mounting legs

Add an additional M4 nut onto each of the 4 mounting leg screws. Screw them down to near the bottom
be keep them loose. These will be used as lock nuts later

### 3. Screw the M3 standoffs onto the leg screws

Screw one of the M3 standoffs onto each of the 4 leg screws. Screw them several mm onto the leg screw
so that they are securely attached, but leave them loose. We will lock them later after levelling the
hotplate.

### 4. Loosely attach the hotplate PCB to the legs

Using 1 M3 machine screw, 1 washer and 1 belleville washer for each corner, attach the hotplate to the
4 legs. The flat washer should go against the underside of the hotplate. Notice that most washers have
one side where the edges are slightly rounded and the opposite side has a slight burr. Put the rounded
side against the PCB to avoid the possibility of that burr cutting through the solder mask and shorting
the heating element. It shouldn't, but just in case.

The narrow side of the belleville washer should be pointed downward toward the standoff. Belleville
washers have a slightly conical shape. They compress slightly under load which provides some pre-load
on the screw/nut threads and some allowance for thermal expansion during heating.

Leave the screws loose at this time. We will tighten things up after levelling the hotplate.

Getting things started can be tricky. For the first two corners, it's generally easier to put the screw
through the corner hole in the hotplate, slip the washers onto the underside, then insert the screw threads
into the standoff and screw it in several turns. After the first two screws are loosely inserted, you
can finish off the other two by carefully sliding the two washers in between the standoff and hotplate
PCB, roughly aligning the holes and then carefully inserting the screw from the top.

### 5. Level the hotplate and lock the leg heights

### 6. Tighten up the hotplate PCB screws

### 7. Bend the power connection wires down to the screw terminals

### 8. Attach power cables and tighten screw terminals

## Hotplate Base

For my hotplate base I use a piece of MDF measuring about 7.5" x 5.5" (190mm x 140mm). Why MDF?
Well:

1. It's cheap and readily available and I have many suitable small off-cuts available to me.
1. It's an electrical insulator and a poor thermal conductor, which is important for the electrical
connections and for limiting the thermal impacts on the surface underneath the hotplate during
operation.
1. It's homogenous in two dimensions and unlikely to twist or warp due to environmental changes
which is important to ensure a long-term stable base that won't place undue stress on the hotplate
PCB.
1. It's relatively unaffected by heat. Unlike plastics like ABS which may warp due to the thermal
cycling or PLA which may soften to the point of being structurally unsound during operation, MDF
should stay relatively flat and strong over many thermal cycles.
1. While it is combustible, this can be managed by ensuring sufficient separation between the
hotplate and the base.

I have used 3D printed bases in the past printed in ABS. These worked reasonably well and allowed
much more complicated internal cable routing, threaded inserts for the base and other nice features.
I also noticed that some elements of the base were warping slowly over time, hence my move away from
ABS. There are higher temperature options like nylon and polycarbonate, but these are also harder to
print and I'm not convinced that they won't also be susceptible to warping due to the thermal cycling.
Plastics just move too much with heat.

### Finishes

While you can just leave the MDF unfinished, it will likely last much better with an appropriate
finish. I recommend high-heat enamel as the most appropriate surface finish for the base. I haven't
ever measured the temperatures reached on the base, I have seen thermal fuse links sometimes leave
burn marks in the MDF when they drop - especially on some of my less successful (read higher temperature)
test runs. During normal operation, the surface probably doesn't exceed the allowable temperature
range for many paints (typically 93°C (199°F)), during a fault the temperature may exceed that by a
large margin. There are some common household finishes that may have ignition temperatures as low as
about 230°C (446°F) which is close to the operating temperature range of our hotplate. You don't
want to finish it with that left over polyurethan only to have that be the component of your whole
build that causes it to catch fire during a fault. Additionally, even if you never have a thermal
fault with your hotplate, non-heat rated finishes may not deal with the thermal cycling well and may
end up cracking and peeling over time, bending a thin sheet of that flammable material up closer to
the hot underside of the hotplate.  High heat enamels are fairly commonly available.  They cost a
little more than regular paint, but I think they are worth it for the peace of mind that you're not
adding some highly flammable component to your DIY heating device. When selecting a finish, look for
one that is specifically rated for use at temperatures exceeding 350°C (662°F). This gives significant
headroom above the normal operating temperature range components on things like barbeques and are
typically rated for use at temperatures up to and sometimes exceeding 350°C (662°F).

### Fabrication

I'm not going to go into details about how specifically I made my bases. It's a flat rectangular piece
of sheet-goods with a few holes drilled in it, possibly with some refinements like rounding over the
edges, rounding the corners and/or finishing it with some high-heat finish. This is a simple thing to
make if you have any basic woodworking capabilities. I will however provide some basic dimensions
and considerations to keep in mind when making it.

The thickness of the MDF is not overly important. Anything that's at least 1/2" or 12mm thick should
be sufficient. I've used 5/8" MDF simply because I had scrap material lying around from previous
projects.

My boards are 7.5" x 5.5" (190mm x 140mm). This provides enough space to mount the hotplate with a
reasonable margin around the edges as well as providing space at one end for the power connections.

I mount the hotplate PCB to be roughly equidistant from the edge of the base on 3 sides. The mounting
holes on my hotplate PCB layouts are 92mm apart, centre-to-centre, although I find it easiest to
simply place a new hotplate PCB on the base, mark the centres of the holes using an awl or similar
tool and then drill through from the top.

The holes for the power connection terminals should be at least 1" apart (25mm) and about 2" (~50mm)
away from the edge of the hotplate. I think my terminals are currently actually 1.25" (~30mm) apart.
A little wider is generally better, but don't go crazy.

On the underside, you'll want to drill a counterbore to allow the heads of the cap screws to be 
recessed into the base. Use something that gives a nice, flat-bottomed hole like a forstner bit.
These should be 5/8" diameter (16mm) to accommodate the large fender washers that will be used to
spread the load on the MDF. Drill these deep enough so as to leave about 1/4" (6mm) of material for
the hardware to hold on to.

![Hotplate Base Dimensions - Top](./images/HotplateBaseDimensions.png)
![Hotplate Base Dimensions - Bottom](./images/HotplateBaseUnderside.png)
