local Rules = {}
Rules.VERSION = 'v6 - Ido Feedback Pass'
Rules.MAX_POWER = 200
Rules.ZONES = {
 {name='Grass', start=80, finish=250, color={92,180,95}, material='Grass'},
 {name='Snow', start=250, finish=420, color={224,240,255}, material='Snow'},
 {name='Desert', start=420, finish=590, color={190,139,82}, material='Sand'},
 {name='Twilight', start=590, finish=760, color={145,111,195}, material='Slate'},
}
Rules.TREES = {
 {name='Meadow Griffin', height=30, x=0, z=160, required=1, coins=25, power=4, rarity='COMMON', speed=27, color={104,208,117}},
 {name='Snow Owl', height=62, x=0, z=330, required=1, coins=65, power=6, rarity='RARE', speed=30, color={87,175,255}},
 {name='Sand Drake', height=95, x=0, z=500, required=1, coins=140, power=9, rarity='EPIC', speed=32, color={244,172,70}},
 {name='Twilight Phoenix', height=135, x=0, z=670, required=1, coins=300, power=12, rarity='LEGENDARY', speed=34, color={190,115,255}},
}
Rules.COLLECTIBLES={}
for zone,config in Rules.TREES do
 for slot=1,3 do
  local item=table.clone(config)
  if slot==2 then item.color={255,112,142} elseif slot==3 then item.color={255,218,85} end
  item.zone=zone
  table.insert(Rules.COLLECTIBLES,item)
 end
end
function Rules.inZone(zone, x, z)
 return x > -90 and x < 90 and z >= zone.start and z < zone.finish
end
function Rules.guardianCanCatch(zone, thiefX, thiefZ, guardX, guardZ, distance)
 return Rules.inZone(zone,thiefX,thiefZ) and Rules.inZone(zone,guardX,guardZ) and distance < 7
end
function Rules.nextTutorial(step, event)
 local events={'train','fly','steal','escape','deliver'}
 return if events[step]==event then step+1 else step
end
function Rules.collectionMerge(old, earned, applied)
 local result={}
 for i=1,#Rules.COLLECTIBLES do
  result[i]=math.max(0,tonumber(old[i]) or 0)+math.max(0,(earned[i] or 0)-(applied[i] or 0))
 end
 return result
end
function Rules.tier(deliveries)
 return math.min(3, math.floor(math.max(0, deliveries) / 3))
end
function Rules.speed(power, deliveries, carrying)
 return (36 + math.sqrt(math.clamp(power, 1, Rules.MAX_POWER)) * 3 + Rules.tier(deliveries) * 3) * (if carrying then 0.92 else 1)
end
function Rules.canSteal(power, required, carrying, available, distance)
 return not carrying and available and distance <= 16
end
function Rules.reward(tree, power, coins, deliveries)
 return math.min(Rules.MAX_POWER, power + tree.power), coins + tree.coins, deliveries + 1
end
return Rules
