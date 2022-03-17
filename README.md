# MuseScore ChordGuess Plugin

MuseScore ChordGuess plugin guesses the chords for a piece of monophonic music. If you have a score with only melody, use this plugin to guess chords from it. This plugin will automatically assign guessed chords to the first note of each of the bar. The algorithm behind the chord guessing is note matching and chord progression formula. Note matching is a term that I come out with. In this context, note matching is a method used to analyses and guess chords by matching the notes in a bar and the possible chords' triad notes. These possible chords can be identified when the key of a song is identified. In music composition, a chord progression stands for a succession of chords. Chord progression formula is a guide or tool for composers and musicians to identify which chord might sound better after another chord. With all of that, this plguin combine these theory and perform chord guessing for a peice of music. This plugin might be useful for those who want to study chord pattern of a song, or beginners who want to play melodies with easy chords for a song. Composers can also use this plugin to guess chords from the melodies or music that they have created.

## Feature
- Guess key for the sheet music
- Show possible chords for that key
- Show possible chords' triad notes (harmony) 
- Allow users to switch its relative major/minor key (if the key is not guessed correctly)
- User can perform multiple times of chord guess to get their intended result
- It show possibility of each possible chords when the user select a particular bar (or the first note in that bar)
- There are 4 different chord guessing algorithm provided for user to choose
- The playback will start whenever the user manual change the chord. This helps user to identify the real chord

## Limitation
- The score must be monophonic (only consists of one staff)
- The gussed chords are not 100% correct

