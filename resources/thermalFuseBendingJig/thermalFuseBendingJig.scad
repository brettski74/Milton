/**
 * Bending jig for creating thermal fuse links for Milton-based hotplate PCBs.
 * 
 * Use 10AWG or 6mm^2 solid copper wire for the fuse element. This is required
 * for ensuring sufficient mass rather than conductivity, although the conductivity
 * doesn't hurt.
 *
 * 1. Use the length gauge on the side to cut wire to correct length.
 * 2. Insert one end of the link into the hole until it touches the bottom.
 * 3. Bend the wire down into the groove.
 * 3. Remove the wire and insert the other end into the hole.
 * 4. Ensure that the first bend is aligned with the direction of the groove.
 * 5. Bend the wire down into the groove. The wire should fit neatly into the groove
 *    that wraps around the end of the jig.
 *
 * It is advised to pre-tin the ends of your link with high-temperature solder before
 * soldering in place on your hotplate. SN100C/CQ100Ge/K100LD or similar solder alloys
 * with approximately 99.3% tin and 0.7% copper or similar and a melting point of 227
 * celsius are recommended.
 *
 * This jig design is part of Milton: The Makeshift Melt-Master - a system for
 * controlling solder reflow hotplates.
 *
 * Copyright (C) 2025 Brett Gersekowski
 *
 * See the file LICENCE.md for full licence details. If you received this file
 * separately and not packaged with the rest of the source code you can find it
 * online at https://github.com/brettski74/Milton
 */
 
$fn = 50;

PI = 3.14159265358979323846264338;
copperDensity = 8940 * 1e3 / 1e9; //(g/mm^3)

// Wire diameter in mm 10AWG = 2.588
AWG_10 = 2.588;

module wireBend(centreRad, wireDiam) {
  rotate([90, 0, 0])
  rotate_extrude(angle = 90, convexity = 2)
    translate([centreRad, 0])
      circle(r=wireDiam/2);
}

module thermalFuseLink(wireDiam=2.588
                     , holeDiam
                     , innerRad=2.588
                     , linkSep=30
                     , linkLen=50
                     , relief=true
                     ) {
  holeDiameter = is_undef(holeDiam) ? wireDiam + 0.6 : holeDiam;
  holeRadius = holeDiameter / 2;
  centreRadius = innerRad + holeDiameter/2;
  // straight vertical section length
  rise = (linkLen - linkSep + (2 - PI)*centreRadius)/2;
  echo(rise = rise);

  if (relief) {
    difference() {
      translate([-linkSep/2,-2.5*holeDiameter,-rise-3])
        cube([linkLen+5, holeDiameter*5, centreRadius + rise + 3]);
      thermalFuseLink(wireDiam=wireDiam
                    , holeDiam=holeDiam
                    , innerRad=innerRad
                    , linkSep=linkSep
                    , linkLen=linkLen
                    , relief=false
                    );
      difference() {
        hull()
          for(i=[-1,1]/2)
            translate([i*linkSep, 0, 0])
              cylinder(r=holeRadius, h=holeRadius+centreRadius);
        
        hull()
          for(j=[-1,1]/2)
            translate([j*(linkSep-2*centreRadius), 0, 0])
              rotate([90,0,0])
                cylinder(r=centreRadius, h=holeDiameter, center=true);
      }
      
      #translate([linkLen+5 - linkSep/2,2.5*holeDiam + 1.25,(centreRadius-rise-3)/2])
        rotate([0,-90,0])
          cylinder(r=2.5, h=linkLen);
    }
  } else {
    translate([linkSep/2 - centreRadius, 0, 0])
      wireBend(centreRad=centreRadius
             , wireDiam=holeDiameter);
    translate([centreRadius - linkSep/2, 0, 0])
      rotate([0,0,180])
        wireBend(centreRad=centreRadius, wireDiam=holeDiameter);

    translate([0,0,centreRadius])
      rotate([0, 90, 0])
        cylinder(r=holeRadius, h=linkSep - 2*centreRadius, center=true);
                       
    for(i=[-1,1]/2) {
      translate([i*linkSep, 0, -rise])
        cylinder(r=holeRadius, h=rise);
    }
  }
}

thermalFuseLink(wireDiam=AWG_10
              , holeDiam=3
              , innerRad=AWG_10
              , linkSep=30
              , linkLen=50
              );