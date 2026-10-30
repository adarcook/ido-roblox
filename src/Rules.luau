local Rules = {}
Rules.VERSION = '0.2 — Flight Forest'
Rules.MAX_POWER = 200
Rules.TREES = {
 {name='Whisper Tree', height=52, x=125, z=10, required=1, coins=25, power=4, rarity='COMMON', speed=27, color={104,208,117}},
 {name='Amber Tree', height=90, x=-140, z=105, required=10, coins=65, power=6, rarity='RARE', speed=33, color={87,175,255}},
 {name='Moon Tree', height=140, x=135, z=215, required=25, coins=140, power=9, rarity='EPIC', speed=38, color={190,115,255}},
 {name='Sun Tree', height=205, x=-180, z=-145, required=45, coins=300, power=12, rarity='LEGENDARY', speed=43, color={255,200,65}},
}
function Rules.tier(deliveries)
 return math.min(3, math.floor(math.max(0, deliveries) / 3))
end
function Rules.speed(power, deliveries, carrying)
 return (36 + math.sqrt(math.clamp(power, 1, Rules.MAX_POWER)) * 3 + Rules.tier(deliveries) * 3) * (if carrying then 0.92 else 1)
end
function Rules.ceiling(power)
 return 85 + math.clamp(power, 1, Rules.MAX_POWER) * 3
end
function Rules.canSteal(power, required, carrying, available, distance)
 return power >= required and not carrying and available and distance <= 16
end
function Rules.reward(tree, power, coins, deliveries)
 return math.min(Rules.MAX_POWER, power + tree.power), coins + tree.coins, deliveries + 1
end
return Rules
