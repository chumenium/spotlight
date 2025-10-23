import random
# --- 形容詞---
ADJECTIVES = [
    "Able", "Agile", "Ample", "Avid", "Aqua", "Anew", "Aged", "Ajar", "Aloof", "Apt",
    "Aware", "Acute", "Amuse", "Arid", "Ashy", "Azure", "Alive", "Agog", "Alien", "Amber",
    "Brave", "Bright", "Brisk", "Brief", "Bliss", "Blond", "Blue", "Big", "Bold", "Brim",
    "Busy", "Best", "Breez", "Basic", "Brown", "Buff", "Bumpy", "Bare", "Black", "Blunt",
    "Calm", "Clear", "Clean", "Cool", "Coy", "Cute", "Curly", "Crisp", "Chill", "Chief",
    "Chic", "Class", "Cloud", "Cold", "Crazy", "Cream", "Crude", "Cubic", "Curvy", "Craft",
    "Crank", "Cliff", "Close", "Charm", "Canny", "Chill", "Cozy", "Clever", "Cheer", "Chill",
    "Civic", "Clair", "Comfy", "Civil", "Clear", "Cooly", "Curvy", "Chill", "Chic", "Chary",
    "Coyly", "Chunk", "Clean", "Cloud", "Clash", "Crush", "Crave", "Curvy", "Cream", "Class",
    "Calm", "Chill", "Cozy", "Cool", "Clear", "Crisp", "Cute", "Cheer", "Chic", "Clair",
    "Craft", "Curvy", "Chill", "Calm", "Clear", "Cool", "Chic", "Crisp", "Clean", "Cute",
    "Cozy", "Curvy", "Chill", "Cheer", "Chic", "Cool", "Calm", "Clear", "Cute", "Clean",
    "Curvy", "Chill", "Cheer", "Chic", "Cool", "Calm", "Clear", "Cute", "Clean", "Curvy",
    "Chill", "Cheer", "Chic", "Cool", "Calm", "Clear", "Cute", "Clean", "Curvy", "Chill",
    "Chic", "Cool", "Calm", "Clear", "Cute", "Clean", "Curvy", "Cheer", "Chill", "Chic",
    "Cool", "Calm", "Clear", "Cute", "Clean", "Curvy", "Chill", "Cheer", "Chic", "Cool",
    "Calm", "Clear", "Cute", "Clean", "Curvy", "Chill", "Cheer", "Chic", "Cool", "Calm",
    "Clear", "Cute", "Clean", "Curvy", "Chill", "Cheer", "Chic", "Cool", "Calm", "Clear",
    "Cute", "Clean", "Curvy", "Chill", "Cheer", "Chic", "Cool", "Calm", "Clear", "Cute",
    "Clean", "Curvy", "Chill", "Cheer", "Chic", "Cool", "Calm", "Clear", "Cute", "Clean",
    "Curvy", "Chill", "Cheer", "Chic", "Cool", "Calm", "Clear", "Cute", "Clean", "Curvy",
    "Daily", "Damp", "Dark", "Deep", "Deft", "Dewy", "Dim", "Dizzy", "Doble", "Dope",
    "Dry", "Dull", "Dune", "Dusk", "Dusty", "Dream", "Drunk", "Dual", "Dandy", "Dense",
    "Dirty", "Dizzy", "Divine", "Docile", "Downy", "Drift", "Droop", "Drowsy", "Dryly", "Dewy",
    "Early", "Eager", "Easy", "Epic", "Even", "Exact", "Extra", "Equal", "Elder", "Empty",
    "Elite", "Eonic", "Evil", "Evict", "Every", "Envy", "Eager", "Equal", "Edgy", "Elfin",
    "Fair", "Fast", "Fancy", "Faint", "Fat", "Fine", "Firm", "Flat", "Fizzy", "Flaky",
    "Fleet", "Flint", "Fluid", "Flush", "Fresh", "Frost", "Full", "Furry", "Fuzzy", "Funny",
    "Gaily", "Giant", "Glad", "Gold", "Good", "Grand", "Gray", "Great", "Green", "Gross",
    "Grown", "Grim", "Gloom", "Giddy", "Globe", "Glory", "Gleam", "Glass", "Glint", "Gummy",
    "Happy", "Hard", "Harsh", "Hazy", "Heavy", "High", "Holy", "Hot", "Hollow", "Hasty",
    "Humid", "Hungry", "Husky", "Huge", "Human", "Humble", "Hasty", "Heady", "Hefty", "Hilly",
    "Handy", "Hairy", "Hasty", "Hoary", "Honey", "Hippy", "Hardy", "Hasty", "Heavy", "Hotly",
    "Heart", "Homey", "Hasty", "Hollow", "Happy", "Humid", "Hungry", "Hefty", "Heady", "Hazy",
    "Handy", "Hilly", "Holy", "Hasty", "Husky", "Humble", "Huge", "Human", "Hasty", "Hasty",
    "Hefty", "Hilly", "Handy", "Hasty", "Heady", "Husky", "Happy", "Hasty", "Hasty", "Hasty",
    "Hasty", "Happy", "Humid", "Hungry", "Hefty", "Heady", "Hazy", "Handy", "Hilly", "Holy",
    "Hasty", "Husky", "Humble", "Huge", "Human", "Hefty", "Heady", "Hazy", "Handy", "Hilly",
    "Holy", "Hasty", "Husky", "Humble", "Huge", "Human", "Hefty", "Heady", "Hazy", "Handy",
    "Hilly", "Holy", "Hasty", "Husky", "Humble", "Huge", "Human", "Hefty", "Heady", "Hazy",
    "Handy", "Hilly", "Holy", "Hasty", "Husky", "Humble", "Huge", "Human", "Hefty", "Heady",
    "Hazy", "Handy", "Hilly", "Holy", "Hasty", "Husky", "Humble", "Huge", "Human", "Hefty",
    "Heady", "Hazy", "Handy", "Hilly", "Holy", "Hasty", "Husky", "Humble", "Huge", "Human",
    "Icy", "Ideal", "Idle", "Ionic", "Iron", "Ivory", "Icky", "Irate", "Itchy", "Ivied",
    "Jade", "Jazzy", "Jolly", "Jumpy", "Just", "Juicy", "Jaded", "Joint", "Joyful", "Jural",
    "Keen", "Kind", "Known", "Kooky", "Kempt", "Kinky", "Knack", "Kiddy", "Kosher", "Keyed",
    "Large", "Lazy", "Lemon", "Light", "Lined", "Lithe", "Livid", "Local", "Lofty", "Lonely",
    "Long", "Loose", "Lovely", "Lucky", "Lunar", "Lush", "Lusty", "Loyal", "Loud", "Lowly",
    "Magic", "Major", "Mild", "Minor", "Mint", "Misty", "Moist", "Moral", "Mossy", "Mourn",
    "Muddy", "Mural", "Murky", "Merry", "Merry", "Metal", "Mirth", "Mirth", "Mossy", "Misty",
    "Neat", "Nervy", "New", "Nifty", "Noble", "Noisy", "Numb", "Naked", "Narrow", "Nifty",
    "Noble", "Nimble", "Nutty", "Nice", "Nifty", "Noble", "Neat", "Nifty", "Noble", "Nifty",
    "Odd", "Old", "Open", "Oval", "Oily", "Okay", "Only", "Out", "Over", "Opal",
    "Pale", "Past", "Plain", "Plush", "Prime", "Pure", "Proud", "Prone", "Plump", "Picky",
    "Penny", "Petty", "Pious", "Polar", "Posh", "Power", "Quick", "Quiet", "Queen", "Quaint",
    "Quirk", "Quasi", "Query", "Quell", "Qualm", "Quartz", "Quest", "Quilt", "Quota", "Quake",
    "Pasty", "Peach", "Perky", "Penny", "Plump", "Plush", "Proud", "Prime", "Pure", "Pious",
    "Picky", "Plain", "Plump", "Proud", "Prime", "Pure", "Pious", "Picky", "Plain", "Plush",
    "Proud", "Prime", "Pure", "Pious", "Picky", "Plain", "Plush", "Proud", "Prime", "Pure",
    "Pious", "Picky", "Plain", "Plush", "Proud", "Prime", "Pure", "Pious", "Picky", "Plain",
    "Plush", "Proud", "Prime", "Pure", "Pious", "Picky", "Plain", "Plush", "Proud", "Prime",
    "Pure", "Pious", "Picky", "Plain", "Plush", "Proud", "Prime", "Pure", "Pious", "Picky",
    "Plain", "Plush", "Proud", "Prime", "Pure", "Pious", "Picky", "Plain", "Plush", "Proud",
    "Prime", "Pure", "Pious", "Picky", "Plain", "Plush", "Proud", "Prime", "Pure", "Pious",
    "Picky", "Plain", "Plush", "Proud", "Prime", "Pure", "Pious", "Picky", "Plain", "Plush",
    "Quick", "Quiet", "Quaint", "Quirky", "Ready", "Rapid", "Rare", "Raw", "Real", "Regal",
    "Rich", "Right", "Ripe", "Rural", "Rosy", "Royal", "Rusty", "Round", "Rough", "Ripe",
    "Sad", "Safe", "Sane", "Sharp", "Short", "Shiny", "Silly", "Slim", "Slow", "Small",
    "Smart", "Smooth", "Soft", "Solid", "Sonic", "Spicy", "Spare", "Speedy", "Spicy", "Stern",
    "Still", "Stout", "Strong", "Sweet", "Sunny", "Super", "Swift", "Tame", "Tall", "Tasty",
    "Tense", "Tidy", "Tiny", "Tough", "Tired", "True", "Tricky", "Trim", "Truer", "Trust",
    "Urban", "Usual", "Used", "Upbeat", "Upper", "Vague", "Valid", "Vast", "Velvet", "Vivid",
    "Vital", "Vocal", "Warm", "Wavy", "Weak", "Weary", "Weird", "Witty", "Wide", "Wild",
    "Windy", "Wise", "Woody", "World", "Worn", "Wry", "Young", "Yummy", "Yearn", "Yonder",
    "Zesty", "Zippy", "Zonal", "Zen", "Zero", "Zany", "Zonal", "Zonal", "Zesty", "Zippy",
    "Quick", "Quiet", "Quaint", "Quirky", "Ready", "Rapid", "Rare", "Raw", "Real", "Regal",
    "Rich", "Right", "Ripe", "Rural", "Rosy", "Royal", "Rusty", "Round", "Rough", "Ripe",
    "Sage", "Safe", "Sane", "Sharp", "Short", "Shiny", "Silly", "Slim", "Slow", "Small",
    "Smart", "Smooth", "Soft", "Solid", "Sonic", "Spicy", "Spare", "Speedy", "Stern", "Still",
    "Stout", "Strong", "Sweet", "Sunny", "Super", "Swift", "Tame", "Tall", "Tasty", "Tense",
    "Tidy", "Tiny", "Tough", "Tired", "True", "Tricky", "Trim", "Truer", "Trust", "Urban",
    "Usual", "Used", "Upbeat", "Upper", "Vague", "Valid", "Vast", "Velvet", "Vivid", "Vital",
    "Vocal", "Warm", "Wavy", "Weak", "Weary", "Weird", "Witty", "Wide", "Wild", "Windy",
    "Wise", "Woody", "World", "Worn", "Wry", "Young", "Yummy", "Yearn", "Yonder", "Zesty",
    "Zippy", "Zonal", "Zen", "Zero", "Zany", "Zonal", "Zesty", "Zippy", "Zonal", "Zesty",
    "Zippy", "Zonal", "Zesty", "Zippy", "Zonal", "Zesty", "Zippy", "Zonal", "Zesty", "Zippy",
    "Zonal", "Zesty", "Zippy", "Zonal", "Zesty", "Zippy", "Zonal", "Zesty", "Zippy", "Zonal",
    "Zesty", "Zippy", "Zonal", "Zesty", "Zippy", "Zonal", "Zesty", "Zippy", "Zonal", "Zesty",
    "Zippy", "Zonal", "Zesty", "Zippy", "Zonal", "Zesty", "Zippy", "Zonal", "Zesty", "Zippy",
    "Zonal", "Zesty", "Zippy", "Zonal", "Zesty", "Zippy", "Zonal", "Zesty", "Zippy", "Zonal"
]

# --- 名詞---
NOUNS = [
    "Air", "Apple", "Arc", "Art", "Axis", "Aqua", "Arrow", "Atom", "Aura", "Ash",
    "Ace", "Area", "Aster", "Axis", "Award", "Arcus", "Anchor", "Angle", "Agent", "Alarm",
    "Bag", "Ball", "Band", "Base", "Bath", "Beam", "Bean", "Bear", "Beat", "Bee",
    "Bell", "Berry", "Bird", "Bite", "Blade", "Bloom", "Block", "Blue", "Boat", "Body",
    "Bone", "Book", "Boot", "Born", "Boss", "Box", "Boy", "Brain", "Brand", "Bread",
    "Break", "Brick", "Bridge", "Brush", "Bug", "Build", "Burn", "Burst", "Bush", "Buzz",
    "Byte", "Cabin", "Cake", "Call", "Calm", "Camp", "Card", "Care", "Case", "Cat",
    "Cell", "Chain", "Chair", "Chart", "Chest", "Chip", "City", "Claim", "Class", "Cloud",
    "Coach", "Coast", "Code", "Coin", "Color", "Comet", "Cook", "Core", "Corn", "Cost",
    "Count", "Court", "Crab", "Craft", "Cream", "Creek", "Crew", "Crop", "Crow", "Crown",
    "Cube", "Cup", "Curve", "Cycle", "Cable", "Camp", "Canal", "Card", "Care", "Carp",
    "Case", "Cast", "Cave", "Cell", "Chain", "Chair", "Charm", "Chart", "Check", "Chest",
    "Chip", "Chime", "Chin", "Chord", "City", "Class", "Clock", "Cloud", "Cloth", "Club",
    "Coast", "Code", "Coin", "Color", "Comet", "Coral", "Core", "Corn", "Cost", "Count",
    "Court", "Crab", "Craft", "Cream", "Creek", "Crew", "Crop", "Crow", "Crown", "Cube",
    "Cup", "Curve", "Cycle", "Cable", "Camp", "Canal", "Card", "Care", "Carp", "Case",
    "Cast", "Cave", "Cell", "Chain", "Chair", "Charm", "Chart", "Check", "Chest", "Chip",
    "Chime", "Chin", "Chord", "City", "Class", "Clock", "Cloud", "Cloth", "Club", "Coast",
    "Code", "Coin", "Color", "Comet", "Coral", "Core", "Corn", "Cost", "Count", "Court",
    "Crab", "Craft", "Cream", "Creek", "Crew", "Crop", "Crow", "Crown", "Cube", "Cup", "Curve",
    "Cycle", "Cable", "Camp", "Canal", "Card", "Care", "Carp", "Case", "Cast", "Cave",
    "Cell", "Chain", "Chair", "Charm", "Chart", "Check", "Chest", "Chip", "Chime", "Chin",
    "Chord", "City", "Class", "Clock", "Cloud", "Cloth", "Club", "Coast", "Code", "Coin",
    "Color", "Comet", "Coral", "Core", "Corn", "Cost", "Count", "Court", "Crab", "Craft",
    "Data", "Day", "Deal", "Deer", "Desk", "Dial", "Dice", "Dirt", "Disk", "Dock",
    "Door", "Dot", "Down", "Dream", "Drift", "Drop", "Drum", "Dust", "Dune", "Dusk",
    "Edge", "Earth", "Ease", "Echo", "Eagle", "Ear", "East", "Egg", "End", "Energy",
    "Era", "Event", "Eye", "Face", "Fact", "Fair", "Farm", "Fast", "Fear", "Feast",
    "Field", "Film", "Fire", "Fish", "Flag", "Flame", "Flash", "Floor", "Flow", "Fog",
    "Food", "Foot", "Force", "Form", "Fort", "Frame", "Friend", "Frost", "Fruit", "Fuel",
    "Fun", "Game", "Gate", "Gift", "Girl", "Glass", "Globe", "Goal", "Gold", "Good",
    "Grain", "Grass", "Green", "Group", "Ground", "Guard", "Guest", "Guide", "Gulf", "Gun",
    "Hair", "Hall", "Hand", "Harm", "Hat", "Head", "Heart", "Heat", "Hill", "Hint",
    "Hive", "Home", "Honey", "Hope", "Horn", "Horse", "Host", "Hour", "House", "Hub",
    "Hue", "Hunt", "Hush", "Hymn", "Hero", "Heal", "Help", "Haze", "Hawk", "Hood",
    "Hole", "Hook", "Howl", "Hug", "Hymn", "Hike", "Hut", "Harp", "Halo", "Herd",
    "Haze", "Hawk", "Heap", "Heel", "Hero", "Hint", "Hire", "Hood", "Hope", "Horn",
    "Hose", "Host", "Hour", "Hunt", "Hush", "Hymn", "Hike", "Hut", "Harp", "Halo",
    "Herd", "Haze", "Heap", "Heel", "Hero", "Hint", "Hire", "Hood", "Hope", "Horn",
    "Hose", "Host", "Hour", "Hunt", "Hush", "Hymn", "Hike", "Hut", "Harp", "Halo",
    "Herd", "Haze", "Heap", "Heel", "Hero", "Hint", "Hire", "Hood", "Hope", "Horn",
    "Hose", "Host", "Hour", "Hunt", "Hush", "Hymn", "Hike", "Hut", "Harp", "Halo",
    "Herd", "Haze", "Heap", "Heel", "Hero", "Hint", "Hire", "Hood", "Hope", "Horn",
    "Hose", "Host", "Hour", "Hunt", "Hush", "Hymn", "Hike", "Hut", "Harp", "Halo",
    "Herd", "Haze", "Heap", "Heel", "Hero", "Hint", "Hire", "Hood", "Hope", "Horn",
    "Hose", "Host", "Hour", "Hunt", "Hush", "Hymn", "Hike", "Hut", "Harp", "Halo",
    "Herd", "Haze", "Heap", "Heel", "Hero", "Hint", "Hire", "Hood", "Hope", "Horn",
    "Hose", "Host", "Hour", "Hunt", "Hush", "Hymn", "Hike", "Hut", "Harp", "Halo",
    "Icon", "Idea", "Ice", "Ink", "Iron", "Item", "Iris", "Issue", "Isle", "Ivory",
    "Jam", "Jet", "Job", "Joy", "Joke", "Judge", "Juice", "Jewel", "Jump", "Jury",
    "Key", "Kind", "King", "Kiss", "Kite", "Knee", "Knob", "Know", "Knight", "Knock",
    "Lake", "Lamp", "Land", "Lane", "Leaf", "Lean", "Leap", "Leg", "Lemon", "Lens",
    "Life", "Light", "Line", "Link", "Lion", "List", "Lock", "Log", "Look", "Loop",
    "Love", "Luck", "Lung", "Lush", "Lava", "Lace", "Lamb", "Lawn", "Leaf", "Leek",
    "Mail", "Main", "Make", "Mall", "Mark", "Mask", "Mass", "Mate", "Meal", "Meat",
    "Meet", "Melt", "Mesh", "Mile", "Mind", "Mine", "Mist", "Mode", "Moon", "More",
    "Moss", "Move", "Muse", "Nest", "Name", "Nail", "Navy", "Need", "News", "Note",
    "Nose", "Nut", "Oak", "Oath", "Oar", "Ocean", "Omen", "Open", "Opal", "Oven",
    "Pack", "Page", "Pain", "Pair", "Palm", "Park", "Part", "Pass", "Path", "Peak",
    "Pear", "Pen", "Perk", "Pet", "Phase", "Phone", "Piano", "Pick", "Pie", "Pine",
    "Pipe", "Plan", "Play", "Plot", "Plug", "Pod", "Poem", "Poet", "Pole", "Pond",
    "Pool", "Port", "Post", "Pot", "Prize", "Proof", "Pull", "Pump", "Punk", "Pupil",
    "Pure", "Push", "Pace", "Pack", "Page", "Palm", "Park", "Part", "Pass", "Path",
    "Peak", "Pear", "Pen", "Perk", "Pet", "Pick", "Pie", "Pine", "Pipe", "Plan",
    "Play", "Plot", "Plug", "Pod", "Poem", "Poet", "Pole", "Pond", "Pool", "Port",
    "Post", "Pot", "Prize", "Proof", "Pull", "Pump", "Punk", "Pupil", "Pure", "Push",
    "Pace", "Pack", "Page", "Palm", "Park", "Part", "Pass", "Path", "Peak", "Pear",
    "Pen", "Perk", "Pet", "Pick", "Pie", "Pine", "Pipe", "Plan", "Play", "Plot",
    "Plug", "Pod", "Poem", "Poet", "Pole", "Pond", "Pool", "Port", "Post", "Pot",
    "Prize", "Proof", "Pull", "Pump", "Punk", "Pupil", "Pure", "Push", "Pace", "Pack",
    "Quest", "Queue", "Quick", "Quill", "Quilt", "Quote", "Quiz", "Rain", "Rake", "Rate",
    "Ray", "Reach", "Read", "Reef", "Rest", "Rice", "Ride", "Ring", "Rise", "Road",
    "Rock", "Role", "Roof", "Room", "Root", "Rose", "Rule", "Run", "Rush", "Rust",
    "Sail", "Sand", "Seat", "Seed", "Self", "Shade", "Shape", "Share", "Shine", "Ship",
    "Shock", "Shop", "Show", "Sign", "Silk", "Sink", "Site", "Size", "Skin", "Sky",
    "Snow", "Soap", "Soil", "Song", "Sort", "Soul", "Soup", "Star", "Step", "Stone",
    "Store", "Storm", "Story", "Stream", "Street", "Study", "Sun", "Surf", "Swim", "Sword",
    "Table", "Tag", "Tail", "Talk", "Task", "Team", "Tear", "Tent", "Test", "Text",
    "Time", "Tool", "Top", "Town", "Track", "Train", "Tree", "Trip", "Truck", "Truth",
    "Tube", "Turn", "Type", "Unit", "User", "Vale", "View", "Vine", "Vote", "Voice",
    "Wall", "Wave", "Way", "Week", "Well", "West", "Wind", "Wing", "Wish", "Wood",
    "Word", "Work", "Yard", "Year", "Youth", "Zone", "Zero", "Zen", "Zoom", "Yarn",
    "Yolk", "Yawn", "Yard", "Yeti", "York", "Zinc", "Zest", "Zone", "Zoom", "Zeal",
    "Quay", "Quiz", "Ridge", "River", "Rope", "Root", "Room", "Rose", "Rule", "Rush",
    "Sack", "Safe", "Sail", "Salt", "Sand", "Seat", "Seed", "Shy", "Shop", "Show",
    "Sign", "Silk", "Sink", "Size", "Skin", "Sky", "Snow", "Soap", "Soil", "Song",
    "Sort", "Soul", "Soup", "Star", "Step", "Stone", "Store", "Storm", "Story", "Stream",
    "Street", "Study", "Sun", "Surf", "Swim", "Sword", "Table", "Tag", "Tail", "Talk",
    "Task", "Team", "Tear", "Tent", "Test", "Text", "Time", "Tool", "Top", "Town",
    "Track", "Train", "Tree", "Trip", "Truck", "Truth", "Tube", "Turn", "Type", "Unit",
    "User", "Vale", "View", "Vine", "Vote", "Voice", "Wall", "Wave", "Way", "Week",
    "Well", "West", "Wind", "Wing", "Wish", "Wood", "Word", "Work", "Yard", "Year",
    "Youth", "Zone", "Zero", "Zen", "Zoom", "Yarn", "Yolk", "Yawn", "Yard", "Yeti",
    "York", "Zinc", "Zest", "Zone", "Zoom", "Zeal","Satosi"
]

def create_username():
    adjective = random.choice(ADJECTIVES)
    noun = random.choice(NOUNS)
    name = adjective + noun
    return name

import psycopg2

# DB接続設定
DB_NAME = "spotlight"
DB_USER = "postgres"
DB_PASSWORD = "kcsf"  # ←適宜変更
DB_HOST = "localhost"
DB_PORT = "5432"

def register_username(userID,token):
    """ユーザ名が存在しなければ登録する"""
    try:
        # PostgreSQLへ接続
        conn = psycopg2.connect(
            dbname=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD,
            host=DB_HOST,
            port=DB_PORT
        )
        cur = conn.cursor()

        # ユーザ名の存在確認
        username = create_username()
        while True:
            try:
                cur.execute("SELECT 1 FROM \"user\" WHERE username = %s", (username,))
                row = cur.fetchone()
                if row is None:
                    break
                else:
                    username = create_username()
            except:
                break
            

        # 登録処理
        userID = str("testUser" + str(random.randint(1, 1000000)))
        cur.execute("INSERT INTO \"user\" (userID,username,token) VALUES (%s,%s,%s)", (userID,username,token))
        conn.commit()
        print(f"'{username}' を新規登録しました。")

        # 終了処理
        cur.close()
        conn.close()

    except psycopg2.Error as e:
        print("データベースエラー:", e)

# 使用例
if __name__ == "__main__":
    register_username()
