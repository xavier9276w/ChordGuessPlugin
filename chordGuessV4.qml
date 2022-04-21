    import MuseScore 3.0
    import QtQuick 2.9
    import QtQuick.Layouts 1.0
    import QtQuick.Controls 2.2
    import QtQuick.Dialogs 1.0
    import Qt.labs.settings 1.0

    MuseScore {
        version:  "3.0";
        description: "A plugin to guess and add simple chords for a melody or monophonic music, user can also change the chord using the plugin.";
        menuPath: "Plugins.ChordGuessV4";
        
        pluginType: "dock"; 
        requiresScore: true;
        dockArea: "left";
        // for debug use
        implicitWidth: 400;
        implicitHeight: 3000;
        property variant black     : "#000000"
        property variant red       : "#ff0000"
        // mode
        // combined method (CPF + note matching)
        // 0 is default one, which is combined method and based on CPF if the first guess was wrong
        // 1 is combined method (Note Matching)
        // 2 is pure CPF
        // 3 is pure note matching
        property var mode              : 0
        property var currentBarNumber  : 0
        property var keyOpt            : -1
        property var guessedChord      : []
        property var probability       : []
        property var notes                  
        property var numOfAccidentals
        property var key
        property var possibleChord
        property var chordHarmonyArray
        property var chordAndHarmonyString
        property var chordWithCounter
        property var nBarsToGuess
        property var dynamicDescription
        property var lastNote
        property var scoreName
        //  function to identify all the notes present in the score
        // tpc is tonal pitch class, each represent a pitch such as (14 = C)
        // the notes pass in is a list
        // tpc	name	tpc	name	tpc	name	tpc	name	tpc	name
        // -1	Fbb	    6	Fb	    13	F	    20	F#	    27	F##
        // 0	Cbb	    7	Cb	    14	C	    21	C#	    28	C##
        // 1	Gbb	    8	Gb	    15	G	    22	G#	    29	G##
        // 2	Dbb	    9	Db	    16	D	    23	D#	    30	D##
        // 3	Abb	    10	Ab	    17	A	    24	A#	    31	A##
        // 4	Ebb	    11	Eb	    18	E	    25	E#	    32	E##
        // 5	Bbb	    12	Bb	    19	B	    26	B#	    33	B##
        function getNoteName (tempNotes) {
            // tpc_str is the array of tpc name in order of tpc table above
            // 0 = C flat flat, 14 = C etc.
            var tpc_str = ["Cbb","Gbb","Dbb","Abb","Ebb","Bbb",
                    "Fb","Cb","Gb","Db","Ab","Eb","Bb","F","C","G","D","A","E","B","F#","C#","G#","D#","A#","E#","B#",
                    "F##","C##","G##","D##","A##","E##","B##","Fbb"]; //tpc -1 is at number 34 (last item).
            
            // we use for loop to check each note and prompt their name
            for (var i = 0; i < tempNotes.length; i++) {  
                if(tempNotes[i].tpc != 'undefined' && tempNotes[i].tpc <=33){
                    if(tempNotes[i].tpc == -1)
                        return tpc_str[34];
                    else
                        return tpc_str[tempNotes[i].tpc];
                }
            }
        }
        
        // function to find the key of the score based on number of accidentals (#/b)
        // positive(+) number indicates n of sharps, negative(-) number indicate n of flats
        function getKey(numOfAccidentals){
            var key = "";
            switch(numOfAccidentals){
                case -7: key = "Cb Major/Ab Minor"; break;
                case -6: key = "Gb Major/Eb Minor"; break;
                case -5: key = "Db Major/Bb Minor"; break;
                case -4: key = "Ab Major/F Minor"; break;
                case -3: key = "Eb Major/C Minor"; break;
                case -2: key = "Bb Major/G Minor"; break;
                case -1: key = "F Major/D Minor"; break;
                case 0: key = "C Major/A Minor"; break;
                case 1: key = "G Major/E Minor"; break;
                case 2: key = "D Major/B Minor"; break;
                case 3: key = "A Major/F# Minor"; break;
                case 4: key = "E Major/C# Minor"; break;
                case 5: key = "B Major/G# Minor"; break;
                case 6: key = "F# Major/D# Minor"; break;
                case 7: key = "C# Major/A# Minor"; break;
                default: return "Undefined ??/ no key?"; // this should never prompt
            }
            return key;
        }

        // function to guess key for the current score
        function guessKey(numOfAccidentals,tempNotes,keyOption){

            var lastNote = tempNotes[tempNotes.length-1][tempNotes[tempNotes.length-1].length-1];
            var tempKey = getKey(numOfAccidentals);

            // check the last note and key
            // keyOption, 0 = major , 1 = minor
            if(keyOption == 0)
                return tempKey.slice(0, tempKey.indexOf("/"));
            else if(keyOption == 1)
                return tempKey.slice(tempKey.indexOf("/")+1 , tempKey.length);

            // first time run just check which key, if cannot identify then set to major
            if(tempKey.includes(lastNote)){
                // if the key is same with the last note, then it is that key
                if(tempKey.startsWith(lastNote) ){
                    keyOpt = 0;
                    return tempKey.slice(0, tempKey.indexOf("/"));
                }
                else{
                    keyOpt = 1;
                    return tempKey.slice(tempKey.indexOf("/")+1 , tempKey.length);
                }
            }
            return tempKey;
        }

        // function to shift every possible chords and harmony to minor chord root position
        function switchToMinor(originalChords, minorChord){
            // if the guessed key is minor, switch it to minor
            for(var i = 0; i < 7; i++){
                var j = i+5;
                if(j > 6)
                    j -= 7;
                minorChord[i]  = [];
                minorChord[i] = originalChords[j];
            }
            return minorChord;
        }

        // function to identify the all possible chords' triad notes for a given key
        // exp:C major, will have (C, Dm, Em. . . .)
        function getPossibleChordHarmony(key, numOfAccidentals){
            var chordHarmony = [[]];
            var accidentals  = ""  ;
            // check if the numOfAccidentals > 0 or not, if it is, then indicate number of sharps
            // negative indicate number of flats, accidentalSequence store the first accidental to last accidental
            // if the key is minor, then create a new 2d array to store chordharmony        
            // if the key is minor then set another minorChord harmony 
            // if the key is minor , we need to change minor chord I starting with major chord V
            if(!key.includes("Major")){
                var isMinor = true ;
                var minorChordHarmony = [[]];
                key = getKey(numOfAccidentals, "ABC");
            }

            if(numOfAccidentals > 0){
                var accidentalMark = "#";
                var accidentalSequence = ["F", "C", "G","D","A","E","B"];
            }else {
                var accidentalMark = "b";
                var accidentalSequence =  ["B", "E", "A","D","G","C","F"];
            }
            
            for(var i = 0; i < Math.abs(numOfAccidentals); i++)
                accidentals = accidentals.concat(accidentalSequence[i] + accidentalMark);   

            // loop to insert the notes of the all seven chords in that major
            for(var i = 0; i < 7; i++){
                var rootAscii, triadAscii, fifthAscii, rootNote,triadNote, fifthNote;
                chordHarmony[i] = [];
                rootAscii = key.charCodeAt() + i;
                triadAscii = rootAscii + 2;
                fifthAscii = rootAscii + 4;

                while(rootAscii > 71){rootAscii -= 7}
                while(triadAscii > 71){triadAscii -=7}
                while(fifthAscii > 71){fifthAscii -=7}
                
                rootNote = String.fromCharCode(rootAscii);
                triadNote = String.fromCharCode(triadAscii);
                fifthNote = String.fromCharCode(fifthAscii);

                // add sharp or flat behind note
                if(accidentals.includes(rootNote))
                    rootNote = rootNote.concat(accidentalMark);
                if(accidentals.includes(triadNote))
                    triadNote = triadNote.concat(accidentalMark);
                if(accidentals.includes(fifthNote))
                    fifthNote = fifthNote.concat(accidentalMark);

                // put those note into chordHarmony array
                chordHarmony[i].push(rootNote);
                chordHarmony[i].push(triadNote);
                chordHarmony[i].push(fifthNote);
            }

            if(isMinor)
                chordHarmony = switchToMinor(chordHarmony,minorChordHarmony);
            return chordHarmony;
        }
        
        // function to get all possible chords in that key
        function getAllPossibleChords(key){
            var chords = [];
            if(!key.includes("Major")){
                var isMinor = true;
                var minorChords = [];
            }
            if("Cb Major/Ab Minor".includes(key)) chords = ["Cb", "Dbm", "Ebm", "Fb" , "Gb" , "Abm", "Bbdim"];
            if("Gb Major/Eb Minor".includes(key)) chords = ["Gb", "Abm", "Bbm", "Cb" , "Db" , "Ebm", "Fdim" ];
            if("Db Major/Bb Minor".includes(key)) chords = ["Db", "Ebm", "Fm" , "Gb" , "Ab" , "Bbm", "Cdim" ];
            if("Ab Major/F Minor".includes(key))  chords = ["Ab", "Bbm", "Cm" , "Db" , "Eb" , "Fm", "Gdim"  ];
            if("Eb Major/C Minor".includes(key))  chords = ["Eb", "Fm" , "Gm" , "Ab" , "Bb" , "Cm", "Ddim"  ];
            if("Bb Major/G Minor".includes(key))  chords = ["Bb", "Cm" , "Dm" , "Eb" , "F"  , "Gm", "Adim"  ];
            if("F Major/D Minor".includes(key))   chords = ["F" , "Gm" , "Am" , "Bb" , "C" , "Dm" , "Edim"    ];
        
            if("C Major/A Minor".includes(key))   chords = ["C",  "Dm", "Em", "F"  , "G", "Am", "Bdim"];

            if("G Major/E Minor".includes(key))   chords = ["G" , "Am" , "Bm" , "C" , "D" , "Em" , "F#dim"];
            if("D Major/B Minor".includes(key))   chords = ["D" , "Em" , "F#m", "G" , "A" , "Bm" , "C#dim"];
            if("A Major/F# Minor".includes(key))  chords = ["A" , "Bm" , "C#m", "D" , "E" , "F#m", "G#dim"];
            if("E Major/C# Minor".includes(key))  chords = ["E" , "F#m", "G#m", "A" , "B" , "C#m", "D#dim"];
            if("B Major/G# Minor".includes(key))  chords = ["B" , "C#m", "D#m", "E" , "F#", "G#m", "A#dim"];
            if("F# Major/D# Minor".includes(key)) chords = ["F#", "G#m", "A#m", "B" , "C#", "D#m", "E#dim"];
            if("C# Major/A# Minor".includes(key)) chords = ["C#", "D#m", "E#m", "F#", "G#", "A#m", "B#dim"];

            if(isMinor)
                chords = switchToMinor(chords,minorChords);
            return chords;
        }

        // function to find harmony/chord symbol from given segment 
        function getSegmentHarmony(segment) {
            var aCount = 0;
            if(segment.annotations.length == 0)
                return null;
            var annotation = segment.annotations[aCount];
            while (annotation) {
                if (annotation.type == Element.HARMONY)
                    return annotation;
                annotation = segment.annotations[++aCount];     
            }
            return null;
        } 

        // function to get the possible chord and their harmony text
        function getChordsAndHarmonyText(possibleChord,chordHarmonyArray){
            var temp = [];
            var RomanNumeral = ["I", "ii", "iii", "IV", "V", "vi", "vii°"];

            for(var i = 0; i < possibleChord.length; i++){
                temp[i] = "";
                if(i == 0)
                    temp[i] += ("Chord[" + RomanNumeral[i] + "] :" + possibleChord[i] + "   \t|Traids:");
                else
                    temp[i] += ("Chord[" + RomanNumeral[i] + "] :" + possibleChord[i] + " \t|Traids:");

                for(var j = 0; j < chordHarmonyArray[i].length; j++)
                    temp[i] += (" " + chordHarmonyArray[i][j]);
            }  
            return temp[0] + "\n" + temp[1] + "\n" + temp[2] + "\n" + 
                    temp[3] + "\n" + temp[4] + "\n" + temp[5] + "\n" + temp[6];
        }

        // function to extract notes from the score
        function extractNotes(){
            var cursor = curScore.newCursor();
            var tempNotes = [[]];
            var bar = 1;
            cursor.rewind(0);
            var currentMeasure = cursor.measure;

            while(currentMeasure){

                var seg = currentMeasure.firstSegment;
                tempNotes[bar-1] = [];

                while (seg.segmentType != Segment.EndBarLine){
                    if(seg.segmentType == Segment.ChordRest){
                        for(var voice = 0; voice < 4; voice++){
                            if(seg.elementAt(voice) && seg.elementAt(voice).type == Element.CHORD){
                                var temp = seg.elementAt(voice).notes;
                                tempNotes[bar-1].push(getNoteName(temp));
                            }
                        }
                    }
                    seg = seg.nextInMeasure;                     
                }
                bar++;
                currentMeasure = currentMeasure.nextMeasure;
            }

            // clear the empty bars at the end with no notes
            var c = tempNotes.length -1;
            while(tempNotes[c].length == 0){
                tempNotes.pop();
                c--;
            }
            return tempNotes;
        }

        // functions to add guessed chords into sheet music
        // nBarToStartAssign indicate the bar to start chord guess, the first bar after upbeat bar
        function addGuessedChords(guessedChord,nBarToStartAssign){
            var cursor = curScore.newCursor();
            cursor.rewind(0);
            // skip upbeat bar
            for(var i = 0; i < nBarToStartAssign; i++)
                cursor.nextMeasure();
            
            for(var i = nBarToStartAssign; i < guessedChord.length; i++){
                var seg = cursor.segment;
                var harmony = getSegmentHarmony(seg);
                addChordSymbol(cursor,harmony,guessedChord[i].color,guessedChord[i].name);
                cursor.nextMeasure();
            }
        }

        // funciton to manually change chord symbol, uses addChordSymbol function
        function changeChordSymbol(name){
            var cursor = curScore.newCursor();
            cursor.rewind(0);
            for(var i = 0; i < currentBarNumber; i++)
                cursor.nextMeasure();
            
            var harmony = getSegmentHarmony(cursor.segment);
            guessedChord[currentBarNumber].name = name;
            guessedChord[currentBarNumber].color = black;
            addChordSymbol(cursor,harmony,black, guessedChord[currentBarNumber].name);
            playFromThisBar(cursor,harmony);
        }

        // function to add harmony element into score
        function addChordSymbol(cursor, harmony,harmonyColor, chordName){
            curScore.startCmd();
            if (harmony) //if chord symbol exists, remove it
                removeElement(harmony);
            
            //chord symbol does not exist, create it
            harmony = newElement(Element.HARMONY);
            harmony.text = chordName;
            harmony.color = harmonyColor;
            harmony.play = true;
            cursor.add(harmony);
            curScore.endCmd();
        }


        // function to initiate playback after manual chord assignment
        function playFromThisBar(cursor,harmony){
            var seg = cursor.segment;
            if(cursor.segment.segmentType == Segment.ChordRest){
                console.log("cursor.segement.elementAt(0) = " + seg.elementAt(0));
                if(seg.elementAt(0).notes){
                    console.log("seg.elementAt(0).notes[0] = " + seg.elementAt(0).notes[0]);
                    console.log("select = " + curScore.selection.select(cursor.segment.elementAt(0).notes[0]));
                }else
                    curScore.selection.select(seg.elementAt(0));
                curScore.selection.select(harmony);
                cmd("play");
            }
        }

        // function to get bar number to start chord guess and the cursor location
        // skip the bars with no notes, when the current bar is not empty, return cursor and bar number
        function checkEmptyAndUpbeatBars(){
            var nBarsToGuess = 0;
            var cursor = curScore.newCursor();
            cursor.rewind(0);
            // empty the array
            while(guessedChord.length !=0)
                guessedChord.pop();
            // skip upbeat bar --- optional 
            while(cursor.element.name != "Chord"){
                cursor.nextMeasure();
                nBarsToGuess++;
                guessedChord.push({index:-1 , name:"" ,color:black, tick:cursor.tick});              
            }
            return {
                nBar: nBarsToGuess,
                cursor: cursor
            }
        }

        // function to return an 2d array that consist of number of note matches with each chord
        // this function use notesMatching algorithm to match with the chord harmony array
        // the result is in 2d array, array[a][b] , a = numberOfBar, b = probability/counterOfThisChordNumber,
        // exp: a[1][0] = 5, in bar 1, there are 5 notes matching with chord 0's triad note
        // exp: a[1][5] = 3, in bar 1, there are 3 notes matching with chord 5's triad note
        function notesMatching(tempNotes, chordsHarmony){
            var highest;
            var chords = [];
            var counter = [[]];
            // perform note matching to find chord that has highest match
            for(var bar = 0; bar < tempNotes.length; bar++){
                highest = 0;
                counter[bar] = [0,0,0,0,0,0,0];
                for(var noteIndex = 0; noteIndex < tempNotes[bar].length; noteIndex++){

                    for(var chordIndex = 0; chordIndex < chordsHarmony.length; chordIndex++){

                        for(var triadNoteIndex = 0; triadNoteIndex < 3 ; triadNoteIndex++){

                            if(tempNotes[bar][noteIndex] == chordsHarmony[chordIndex][triadNoteIndex]){
                                counter[bar][chordIndex] +=1;
                            }
                        }
                        if(counter[bar][chordIndex] > highest){
                            highest = counter[bar][chordIndex];
                        }
                    }
                }
            }
            return counter;
        }

        // function to return an array of indexes that has highest value
        // exp input counter = [0, 5, 5, 5 ,1 ,3 ,4]
        // return temp = [1,2,3] - because index 1 2 3 has highest number (5)
        function findHighestAmong(counter){
            var temp = [];
            var result = [];
            var highest = 0;
            // find the highest 
            highest = Math.max.apply(null, counter);

            for(var i = 0; i < counter.length; i++){
                if(counter[i] == highest)
                    temp.push(i);
            }
            return temp;
        }

        // function to guess chord with the selected mode
        function guessChordWithMode(cursor,chordsWithCounter,nBarsToGuess,chordToStart,mode){
            console.log("------------GUESSING CHORD WITH MODE :" + mode + " -----------------------");
            var lastChordNumber;
            var initialGuessChords = [[]];
            var counter = 0;
   
            // nBarsToGuess not neccessary to be 0, because chord guess might start from bar 4
            // exp: previous bars, bar 0, bar1, bar2, bar3 all are empty bars / upbeat bars
            // default chord to start is chord I (chord 0)
            if(chordToStart == null)
                chordToStart = 0;

            initialGuessChords[nBarsToGuess] = [];
            initialGuessChords[nBarsToGuess].push(chordToStart);
            guessedChord.push({index:chordToStart, name:possibleChord[chordToStart],color:black,tick:cursor.tick});
            lastChordNumber = chordToStart;
            nBarsToGuess++;
            // proceed to remaining bars
            while(nBarsToGuess < chordsWithCounter.length){
                var finalguessedChord;
                var uncertain = false;
                initialGuessChords[nBarsToGuess] = [];

                // find CPFResult (chord progression formula result)
                // find HMC (hightest matching chords)
                var CPFResult = checkChordProgressionFormula(lastChordNumber,null);
                var HMC = findHighestAmong(chordsWithCounter[nBarsToGuess]);

                // mode == 0  || 1 
                if(mode == 0 || mode == 1){
                    for(var i = 0; i < CPFResult.length; i++){
                        for(var j = 0; j < HMC.length; j++){
                            // every matching chord will be added into guessedChords
                            // to decide which one to be guessed is on later decision
                            // normally will go for first one, but can try rand also
                            if(CPFResult[i] == HMC[j])
                                initialGuessChords[nBarsToGuess].push(CPFResult[i]);
                        }
                    }
                }
                // which mean CPFResult != HMC, there doesnt exist a chord matching between two algorithm
                // depending on different mode, the second chord was guess either using CPFResult or HMC
                if(initialGuessChords[nBarsToGuess].length == 0 && (mode == 0 || mode == 2)){
                    for(var i = 0; i < CPFResult.length; i++){
                        if(mode == 0)
                            uncertain = true;
                        initialGuessChords[nBarsToGuess].push(CPFResult[i]);
                    }
                }
                if(initialGuessChords[nBarsToGuess].length == 0 && (mode == 1 || mode == 3)){
                        for(var i = 0; i < HMC.length; i++){
                        if(mode == 1)
                            uncertain = true;
                        initialGuessChords[nBarsToGuess].push(HMC[i]);
                    }  
                }
       
                // Implement logic to determine which chord to choose from
                // default : always pick the first one
                // finalguessedChord = guessedChord[nBarsToGuess][0]
                // or: randomized among them
                if(initialGuessChords[nBarsToGuess].length > 1){
                    var rand = Math.floor(Math.random() * initialGuessChords[nBarsToGuess].length);
                    finalguessedChord = initialGuessChords[nBarsToGuess][rand];
                }
                else
                    finalguessedChord = initialGuessChords[nBarsToGuess][0];
                
                // console.log("-------------------------------BAR " + nBarsToGuess + " ---------------------------------")
                // console.log("CPFResult[" + nBarsToGuess + "] = " + CPFResult);
                // console.log("HMC[" + nBarsToGuess + "] = " + HMC);
                // console.log("InitalGuessChords[" + nBarsToGuess + "] = " + initialGuessChords[nBarsToGuess]);
                // console.log("finalguessedChord[" + nBarsToGuess + "] = " + finalguessedChord)

                // declaring properties to store in guessedChord object
                var tempIndex = finalguessedChord;
                var tempName = possibleChord[tempIndex];
                var tempTick = cursor.tick;
                // if uncertain use Red Chord
                if(uncertain)
                    var tempColor = red;
                else
                    var tempColor = black;

                guessedChord.push({index: tempIndex, name: tempName, color:tempColor, tick:tempTick});            
                lastChordNumber = finalguessedChord;
                nBarsToGuess++;
                cursor.nextMeasure();
            }        
        }

        // function to returns a array of next possible chord according to chord progression formula
        function checkChordProgressionFormula(lastChordNumber){
            var nextChord = [];
            switch (lastChordNumber){
                // chordV tend to resolve in chordI
                // 0 = I
                // 1 = II 
                // 2 = III  
                // 3 = IV
                // 4 = V 
                // 5 = VI
                // 6 = VII
                case 0:
                    nextChord = [0,1,2,3,4,5,6];
                    break;
                case 1:
                    nextChord = [4,6];
                    break;
                case 2:
                    nextChord = [3,5];
                    break;
                case 3:
                    nextChord = [1,4,6];
                    break;
                case 4:
                    nextChord = [0,6];
                    break;
                case 5:
                    nextChord = [1,3];
                    break;
                case 6:
                    nextChord = [0,2,5];
                    break;
                default: 
                    console.log("Error Chord");
                    break;
            }
            return nextChord;
        }

        // function to guess chord
        function guessChord(){   
            if (typeof curScore === 'undefined')   
                Qt.quit();
            // check if the score is same, if not, set the keyOpt to -1
            if(scoreName!= curScore.scoreName){
                keyOpt = -1;
                scoreName = curScore.scoreName;
            }

            // first we need to know all notes inside the score
            notes = extractNotes();
            
            // after we gather all the notes we want, we can process to determine it is a minor or major key
            numOfAccidentals = curScore.keysig;
            key = guessKey(numOfAccidentals,notes,keyOpt);
            
            // find all possible chord and their harmony in that key
            possibleChord = getAllPossibleChords(key);
            chordHarmonyArray = getPossibleChordHarmony(key, numOfAccidentals);
            chordAndHarmonyString = getChordsAndHarmonyText(possibleChord,chordHarmonyArray);
        
            // check the first note to avoid upbeat, and set cursor to the upbeat bar
            var a = checkEmptyAndUpbeatBars();
            nBarsToGuess = a.nBar;
            var cursor = a.cursor;  

            // find chordWithCounter for probability table
            chordWithCounter = notesMatching(notes,chordHarmonyArray);

            // perform chord guess and assign chords to current score
            guessChordWithMode(cursor,chordWithCounter,nBarsToGuess,null,mode);
            addGuessedChords(guessedChord,nBarsToGuess);
        }

        // function to find bar for a given tick, return the bar number
        function findBar(targetTick){
            var bar = 0;
            var i = true;
            var targetTick;
            var curTick = 0;
            var cursor = curScore.newCursor();
            cursor.rewind(0);
            while(curTick != targetTick && curTick < targetTick && i){
                i = cursor.nextMeasure();
                curTick = cursor.tick;
                bar++;
            }
            if(curTick > targetTick || !i){
                bar = -1;
            }
            return bar;
        }

        // function to find the possibility of the current bar
        function changeProbability(nBar){
            var temp = [];
            var highest = 0;
            highest = Math.max.apply(null,chordWithCounter[nBar]);
            var ppc = 100/(highest+1); // percentage per counter(ppc)

            for(var i = 0; i < chordWithCounter[nBar].length; i++)
                temp.push((chordWithCounter[nBar][i] * ppc).toFixed(2));
        
            return temp;
        }

        // function to change plugin description
        function changeDynamicDescription(string){
            if(string.length == 0)
                dynamicDescription = "<b>Chord Guess Plugin</b> <br><br> <i>This plugin guess chords to each bar automatically based on chord formula progression and notes analysis</i>";
            else
                dynamicDescription = string;
        }

        onRun: {
            guessChord();
        }

        onScoreStateChanged: {
            console.log("State changed");
            if(state.selectionChanged){
                probability = [];
                console.log("selection changed");
                if(curScore.selection.elements.length == 0){
                    console.log("NOTHING WAS SELECTED");
                }
                else if(curScore.selection.elements.length > 0){
                    if(curScore.selection.elements[0].type == Element.HARMONY){
                        var firstElement = curScore.selection.elements[0];
                        var seg = firstElement.parent;
                        currentBarNumber = findBar(seg.tick);
                    } 
                    else {
                        var cursor = curScore.newCursor();
                        cursor.rewind(1);
                        if(cursor.segment != null){
                            var a = cursor.segment;
                            currentBarNumber = findBar(a.tick);
                        }else{
                            currentBarNumber = -1;
                        }
                    }
                    if(currentBarNumber < 0)
                        probability = [];
                    else 
                        probability = changeProbability(currentBarNumber);
                }
            }
        }
        
        // GUI of the plugin
        Rectangle{
            id: root
            color: "lightblue"
            anchors.fill: parent
            Rectangle{
                id:descriptionText
                color:"white"
                implicitHeight:{
                    if(root.height/4 >= 100)
                        return 100
                    else
                        return root.height/5
                }
                border{
                    color:"black"
                    width:2
                }
                anchors{
                    top: root.top; topMargin: 10
                    left: root.left; leftMargin: 10
                    right: root.right; rightMargin: 10
                }
                ScrollView {
                    id: view
                    clip: true
                    topPadding: 5
                    leftPadding: 10
                    rightPadding: 5
                    bottomPadding: 10
                    contentWidth: availableWidth
                    anchors.fill: parent
                    Text{
                        anchors{
                            fill: parent
                        }
                        wrapMode: Text.WordWrap
                        text: dynamicDescription
                        Component.onCompleted:{
                            changeDynamicDescription("");
                        }
                    }
                }
            }

            Rectangle{
                id: keyText
                clip: true
                color: "transparent"
                width: descriptionText.width/2
                height: (modeColumn.height * 2/3)
                anchors{
                    left: descriptionText.left; //leftMargin: 10
                    top: descriptionText.bottom; topMargin: 5
                }
                MouseArea{
                    hoverEnabled: true
                    anchors.fill: parent
                    onEntered:{
                        changeDynamicDescription("");
                    }
                }
                Text{
                    wrapMode: Text.WordWrap
                    text: "Key of this score: " + key
                    anchors.fill: parent
                    font{
                        bold: true
                        pixelSize: 18
                    }
                }
            }

            Button{
                id: switchKeyButton
                highlighted: true
                text: "Switch Key" 
                implicitWidth: keyText.width
                anchors{
                    left: keyText.left
                    bottom: modeColumn.bottom
                    top: keyText.bottom; topMargin: 5
                }

                onClicked:{
                    if(keyOpt == 0 || keyOpt == -1)
                        keyOpt = 1;
                    else if(keyOpt == 1)
                        keyOpt = 0;
                    guessChord();
                }
            }

            ColumnLayout {
                // chord guess mode
                id: modeColumn 
                implicitWidth: root.width/2
                anchors{
                    right: descriptionText.right
                    left: switchKeyButton.right; leftMargin: 10
                    top:  descriptionText.bottom; topMargin: 10
                }
                Text{
                    text: "Chord guessing mode:"
                    Layout.preferredHeight: 20
                    font.pixelSize: 15
                    MouseArea{
                        id: modeDescription
                        hoverEnabled: true
                        anchors.fill: parent
                        ToolTip {
                            delay: 500
                            clip: true
                            text: "click to see details"
                            visible: parent.containsMouse
                        }
                        onClicked:{changeDynamicDescription("<b>Chord <small>Guess Mode</small></b><br>\
                                            <br><i><b>HNM (Harmony note matching)</b> determine chord by matching the notes in bar and the chords' triad notes</i></small>\
                                            <br><i><b>CPF (Chord progression fomula)</b> determine chord by guessing potential chords after the previous chord</i>");
                        }
                    } 
                }
                // ---------button 1-------------
                RadioButton {
                    id: button1
                    text: qsTr("First (CPF+HNM)")
                    checked: true
                    Layout.preferredHeight: 20
                    ToolTip {
                        clip: true
                        delay: 500
                        visible: button1.hovered
                        text: "Combine two approach, if there is no chord\nmatch both algorithm guess a chord using CPF"
                    }
                    indicator:  Rectangle {
                        y:2 ; x:2
                        border.color: "black"
                        width:16; height: 16; radius: 8
                        Rectangle {
                            width: 8
                            height: 8
                            radius: 3
                            color: "red"
                            x: parent.radius/2
                            y: parent.radius/2
                            visible: button1.checked
                        }
                    }
                    contentItem: Text {
                        color: "black"
                        text: button1.text
                        opacity: button1.checked ? 1.0 : 0.6
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: button1.indicator.width
                    }
                    onClicked:{
                        mode = 0;
                        console.log("mode = " + mode);
                    }
                }
                //--------------button 2-----------
                RadioButton {
                    text: qsTr("Second (HNM+CPF)")
                    id: button2
                    Layout.preferredHeight: 20
                    ToolTip {
                        delay: 500
                        clip: true
                        visible: button2.hovered
                        text: "Combine two approach, if there is no chord\nmatch both algorithm guess a chord using HMN"
                    }
                    indicator:  Rectangle {
                        y:2 ; x:2
                        border.color: "black"
                        width:16; height: 16; radius: 8
                        Rectangle {
                            width: 8
                            height: 8
                            radius: 3
                            color: "red"
                            x: parent.radius/2
                            y: parent.radius/2
                            visible: button2.checked
                        }
                    }
                    contentItem: Text {
                        color: "black"
                        text: button2.text
                        opacity: button2.checked ? 1.0 : 0.6
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: button2.indicator.width
                    }
                    onClicked:{
                        mode = 1;
                        console.log("mode = " + mode);
                    }
                }
                //-- -------------button3 ---------------
                RadioButton {
                    id: button3
                    text: qsTr("Third (CPF only)")
                    Layout.preferredHeight: 20
                    ToolTip {
                        delay: 500
                        clip: true
                        visible: button3.hovered
                        text: "Guess chords using Chord Progression Formula only"
                    }
                    indicator:  Rectangle {
                        y:2 ; x:2
                        border.color: "black"
                        width:16; height: 16; radius: 8
                        Rectangle {
                            width: 8
                            height: 8
                            radius: 3
                            color: "red"
                            x: parent.radius/2
                            y: parent.radius/2
                            visible: button3.checked
                        }
                    }
                    contentItem: Text {
                        color: "black"
                        text: button3.text
                        opacity: button3.checked ? 1.0 : 0.6
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: button3.indicator.width
                    }
                    onClicked:{
                        mode = 2;
                        console.log("mode = " + mode);
                    }
                }
                // ----------------- button 4 --------------------
                RadioButton {
                    id: button4
                    text: qsTr("Fourth (HNM only)")
                    Layout.preferredHeight: 20
                    ToolTip {
                        delay: 500
                        clip: true
                        visible: button4.hovered
                        text: "Guess chords using Harmony Note Matching only"
                    }
                    indicator: Rectangle {
                        y:2 ; x:2
                        border.color: "black"
                        width:16; height: 16; radius: 8
                        Rectangle {
                            width: 8
                            height: 8
                            radius: 3
                            color: "red"
                            x: parent.radius/2
                            y: parent.radius/2
                            visible: button4.checked
                        }
                    }
                    contentItem: Text {
                        color: "black"
                        text: button4.text
                        opacity: button4.checked ? 1.0 : 0.6
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: button4.indicator.width
                    }
                    onClicked:{
                        mode = 3;
                        console.log("mode = " + mode);
                    }
                }
            }

            Rectangle{
                // show possible chords and harmony notes
                id: possibleChordText  
                clip: true
                color: "white"
                height: {
                    if(root.height/4 > 135)
                        return 135;
                    return root.height/4;
                }
                anchors{
                    top: modeColumn.bottom; topMargin: 20
                    left: root.left; leftMargin: 10
                    right: root.right; rightMargin: 10
                }
                border{
                    width:2
                    color:black
                }
                ScrollView {
                    leftPadding: 10
                    topPadding: 5
                    bottomPadding: 10
                    rightPadding: 5
                    anchors.fill: parent
                    Text{
                        anchors.fill: parent
                        text:{"Possible chord and their triad notes:\n"+chordAndHarmonyString}                    
                    }
                }
            }

            Rectangle{
                // probability table
                id: possRect 
                clip: true
                color: "black"
                anchors{
                    left: descriptionText.left 
                    right: descriptionText.right 
                    bottom: guessChordButton.top ; bottomMargin:10
                    top: possibleChordText.bottom; topMargin:10
                }
                ScrollBar{
                    id: vbar
                    active: true
                    hoverEnabled: true
                    orientation: Qt.Vertical
                    size: possRect.height/200
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    z:1
                }
                Grid{
                    id: possGrid
                    clip: true
                    spacing: 0
                    columns: 2; rows: 8
                    y: -vbar.position * 200
                    horizontalItemAlignment: Grid.AlignHCenter
                    height:{
                        if(possRect.height>200)
                            return possRect.height;
                        else 
                            return 200;
                    }
                    anchors{
                        left: parent.left
                        right: parent.right
                        top:{
                            if(possRect.height>= 200)
                                return parent.top;
                        }
                        bottom:{
                            if(possRect.height>= 200)
                                return parent.bottom;
                        }
                    }
                    
                    Repeater{
                        id: gridRepeater
                        model: ["CHORD NAME" , "PROBABILITY", ""+ possibleChord[0] , 
                                ""+ probability[0] + "%", ""+ possibleChord[1] , 
                                ""+ probability[1] + "%", ""+ possibleChord[2] , 
                                ""+ probability[2] + "%", ""+ possibleChord[3] ,
                                ""+ probability[3] + "%", ""+ possibleChord[4] , 
                                ""+ probability[4] + "%", ""+ possibleChord[5] , 
                                ""+ probability[5] + "%", ""+ possibleChord[6] , 
                                ""+ probability[6] + "%"]
                        Rectangle{
                            id: possEntity
                            clip: true
                            color: "lightyellow"
                            width: possGrid.width/ possGrid.columns - border.width
                            height:{
                                if(possGrid.height/possGrid.rows <= 25)
                                    return 25;
                                else
                                    return possGrid.height/possGrid.rows;
                            }
                            MouseArea{
                                id: mouse2
                                enabled: false
                                anchors.fill: parent
                                onPressed:{
                                    parent.color = "#F9E79F";
                                }
                                onReleased:{
                                    parent.color = "#F4D03F";
                                }
                                onClicked: {
                                    changeChordSymbol(model.modelData);
                                }
                            }    
                            Component.onCompleted:{
                                if(model.index != 0 && model.index % 2 == 0){
                                    mouse2.enabled = true;
                                    possEntity.color = "#F4D03F";
                                    //possEntity.border.color = "white"
                                }
                            }
                            border{
                                width: 1
                                color: black
                            }
                            Text{
                                clip: true
                                color: black
                                text: model.modelData
                                anchors{
                                    verticalCenter: parent.verticalCenter
                                    horizontalCenter: parent.horizontalCenter
                                }                            
                                font{
                                    bold: true
                                    pixelSize: 15
                                }
                            }
                        }
                    }              
                }
            }
            Button{
                // guess chord button
                id: guessChordButton
                clip: true
                width: text.width
                highlighted: true
                text: "Guess Chord"
                anchors{
                    bottomMargin: 10
                    bottom: root.bottom
                    horizontalCenter: root.horizontalCenter
                }
                onClicked:{
                    guessChord();
                }
            }
        }
    }
