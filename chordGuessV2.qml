import MuseScore 3.0
import QtQuick 2.9
import QtQuick.Layouts 1.0
import QtQuick.Controls 2.2
import QtQuick.Dialogs 1.0
import Qt.labs.settings 1.0

MuseScore {
    version:  "3.0";
    description: "Guess chord based on the notes bar by bar, based on some logic.";
    menuPath: "Plugins.ChordGuessV3";
    pluginType: "dock";
    requiresScore: true;
    dockArea: "left";
    width:parent.width;
    height:parent.height;
    
    property variant black     : "#000000"
    property variant red       : "#ff0000"
    property variant green     : "#00ff00"
    property variant blue      : "#0000ff"
    property var numOfAccidentals : curScore.keysig;
    // This method int will have 4 possible values 0, 1, 2,3 
    // combined method (CPF + note matching)
    // 0 is default one, which is combined method and based on CPF if the first guess wrong
    // 1 is combined method (Note Matching)
    // 2 is pure CPF
    // 3 is pure note matching
    property var mode: 0;
    property var notes;
    property var key;
    property var possibleChord;
    property var chordHarmonyArray;
    property var chordAndHarmonyString;
    property var guessedChord: [];
    property var chordWithCounter;
    property var chordWithProgression;
    property var nBarsToGuess;
    property var probability: []; 
    property var currentBarNumber: 0;
    property var keyOpt : -1;
    property var dynamicDescription
    property var lastNote;
    // nameNote function is used to identify all the notes present in the score
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
                    return tpc_str[34]
                else
                    return tpc_str[tempNotes[i].tpc]
            }
        }
    }
    
    // findKey function is used to find the key of the score based on number of accidentals (#/b)
    // positive(+) number indicates n of sharps, negative(-) number indicate n of flats
    function getKey(numOfAccidentals){
        var key = "";
        // possibleChordsInKey shows all possible chords in this key
        var possibleChordsInKey = []
        switch(numOfAccidentals){
            case -7: key = "Cb Major/Ab minor"; break;
            case -6: key = "Gb Major/Eb minor"; break;
            case -5: key = "Db Major/Bb minor"; break;
            case -4: key = "Ab Major/F minor"; break;
            case -3: key = "Eb Major/C minor"; break;
            case -2: key = "Bb Major/G minor"; break;
            case -1: key = "F Major/D minor"; break;
            case 0: key = "C Major/A minor"; break;
            case 1: key = "G Major/E minor"; break;
            case 2: key = "D Major/B minor"; break;
            case 3: key = "A Major/F# minor"; break;
            case 4: key = "E Major/C# minor"; break;
            case 5: key = "B Major/G# minor"; break;
            case 6: key = "F# Major/D# minor"; break;
            case 7: key = "C# Major/A# minor"; break;
            default: return "Undefined ??/ no key?"; // this should never prompt
        }
        return key;
    }

    // function to guess key
    function guessKey(numOfAccidentals,tempNotes,keyOption){
        var lastNote = tempNotes[tempNotes.length-1][tempNotes[tempNotes.length-1].length-1];
        var tempKey = getKey(numOfAccidentals)
        // check the last note and key
        // keyOption, 0 = major , 1 = minor
        if(keyOption == 0){
            return (tempKey.slice(0, tempKey.indexOf("/")))
        }else if(keyOption == 1){
            return (tempKey.slice(tempKey.indexOf("/")+1 , tempKey.length))
        }
        // first time run just check which key, if cannot identify then set to major
        if(tempKey.includes(lastNote)){
            // if the key is same with the last note, then it is that key
            if(tempKey.startsWith(lastNote) ){
                keyOpt = 0;
                return (tempKey.slice(0, tempKey.indexOf("/")))
            }
            else{
                keyOpt = 1;
                return (tempKey.slice(tempKey.indexOf("/")+1 , tempKey.length))
            }
        }
        keyOpt = 0;
        return tempKey;
    }

    // function to switch key
    function switchKey(){
        var tempKey;
        var a = [];
        var b = [[]];
        tempKey = getKey(numOfAccidentals)
        //switch key to minor
        if(key.includes("Major")){
            possibleChord = switchToMinorOrMajor(possibleChord,a,1);
            chordHarmonyArray = switchToMinorOrMajor(chordHarmonyArray,b,1);
            key = tempKey.slice(tempKey.indexOf("/")+1 , tempKey.length)
        }
        //switch key to minor
        else{
            possibleChord = switchToMinorOrMajor(possibleChord,a,0);
            chordHarmonyArray = switchToMinorOrMajor(chordHarmonyArray,b,0);
            key = tempKey.slice(0, tempKey.indexOf("/"))
        }
        chordAndHarmonyString = getChordsAndHarmonyText(possibleChord,chordHarmonyArray);
    }
    // this function will swap the chord or chordHarmony to minor or major
    // indicator, 0 switch to major , 1 switch to minor
    function switchToMinorOrMajor(originalChords, minorChord,indicator){
        // switch to major
        if(indicator == 0){
            for(var i = 0; i < 7; i++){
                var j = i+2;
                if(j > 6)
                    j -= 7;
                minorChord[i]  = []
                minorChord[i] = originalChords[j]
            }
        }else{
            for(var i = 0; i < 7; i++){
                var j = i+5;
                if(j > 6)
                    j -= 7;
                minorChord[i]  = []
                minorChord[i] = originalChords[j]
            }
        }
        return minorChord
    }
    // identify the possible chord in the key
    // The possible chord is for major key: exp:C major, will have (C, Dm, Em. . . .)
    // if want shift to minor key, then the 
    function getPossibleChordHarmony(key, numOfAccidentals){
        var chordHarmony = [[]]
        var accidentals = ""
        // check if the numOfAccidentals > 0 or not, if it is, then indicate number of sharps
        // negative indicate number of flats, accidentalSequence store the first accidental to last accidental
        // if the key is minor, then create a new 2d array to store chordharmony        
        // if the key is minor then set another minorChord harmony 
        // if the key is minor , we need to change minor chord I starting with major chord V
        if(!key.includes("Major")){
            var minorChordHarmony = [[]]
            key = getKey(numOfAccidentals, "ABC")
            var isMinor = true 
        }

        if(numOfAccidentals > 0){
            var accidentalSequence = ["F", "C", "G","D","A","E","B"]
            var accidentalMark = "#";
        }else {
            var accidentalSequence =  ["B", "E", "A","D","G","C","F"]
            var accidentalMark = "b";
        }
        
        // if the key is flat key
        for(var i = 0; i < Math.abs(numOfAccidentals); i++){
            accidentals = accidentals.concat(accidentalSequence[i] + accidentalMark)
        }      
        // loop to insert the note of the all seven chord in that major
        // for C major key, chordHarmony[0] is C chord, [1] is D minor key and so on...
        for(var i = 0; i < 7; i++){
            var rootAscii, triadAscii, fifthAscii, rootNote,triadNote, fifthNote;
            chordHarmony[i] = []
            rootAscii = key.charCodeAt() + i;
            triadAscii = rootAscii + 2;
            fifthAscii = rootAscii + 4;

            while(rootAscii > 71){rootAscii -= 7}
            while(triadAscii > 71){triadAscii -=7}
            while(fifthAscii > 71){fifthAscii -=7}
            
            rootNote = String.fromCharCode(rootAscii)
            triadNote = String.fromCharCode(triadAscii)
            fifthNote = String.fromCharCode(fifthAscii)

            // add sharp or flat behind note
            if(accidentals.includes(rootNote))
                rootNote = rootNote.concat(accidentalMark)
            if(accidentals.includes(triadNote))
                triadNote = triadNote.concat(accidentalMark)
            if(accidentals.includes(fifthNote))
                fifthNote = fifthNote.concat(accidentalMark)

            // put those note into chordHarmony array
            chordHarmony[i].push(rootNote)
            chordHarmony[i].push(triadNote)
            chordHarmony[i].push(fifthNote)
        }

        if(isMinor){
            chordHarmony = switchToMinorOrMajor(chordHarmony,minorChordHarmony,1)
        }

        return chordHarmony
    }
    
    // this function return all possible chord in that key
    function getAllPossibleChords(key){
        var chords = []
        if(!key.includes("Major")){
            var minorChords = []
            var isMinor = true 
        }
        if("Cb Major/Ab minor".includes(key)) chords = ["Cb", "Dbm", "Ebm", "Fb" , "Gb" , "Abm", "Bbdim"];
        if("Gb Major/Eb minor".includes(key)) chords = ["Gb", "Abm", "Bbm", "Cb" , "Db" , "Ebm", "Fdim" ];
        if("Db Major/Bb minor".includes(key)) chords = ["Db", "Ebm", "Fm" , "Gb" , "Ab" , "Bbm", "Cdim" ];
        if("Ab Major/F minor".includes(key))  chords = ["Ab", "Bbm", "Cm" , "Db" , "Eb" , "Fm", "Gdim"  ];
        if("Eb Major/C minor".includes(key))  chords = ["Eb", "Fm" , "Gm" , "Ab" , "Bb" , "Cm", "Ddim"  ];
        if("Bb Major/G minor".includes(key))  chords = ["Bb", "Cm" , "Dm" , "Eb" , "F"  , "Gm", "Adim"  ];
        if("F Major/D minor".includes(key))   chords = ["F" , "Gm" , "Am" , "Bb" , "C" , "Dm" , "Edim"    ];
    
        if("C Major/A minor".includes(key))   chords = ["C",  "Dm", "Em", "F"  , "G", "Am", "Bdim"];

        if("G Major/E minor".includes(key))   chords = ["G" , "Am" , "Bm" , "C" , "D" , "Em" , "F#dim"];
        if("D Major/B minor".includes(key))   chords = ["D" , "Em" , "F#m", "G" , "A" , "Bm" , "C#dim"];
        if("A Major/F# minor".includes(key))  chords = ["A" , "Bm" , "C#m", "D" , "E" , "F#m", "G#dim"];
        if("E Major/C# minor".includes(key))  chords = ["E" , "F#m", "G#m", "A" , "B" , "C#m", "D#dim"];
        if("B Major/G# minor".includes(key))  chords = ["B" , "C#m", "D#m", "E" , "F#", "G#m", "A#dim"];
        if("F# Major/D# minor".includes(key)) chords = ["F#", "G#m", "A#m", "B" , "C#", "D#m", "E#dim"];
        if("C# Major/A# minor".includes(key)) chords = ["C#", "D#m", "E#m", "F#", "G#", "A#m", "B#dim"];

        if(isMinor){
            chords = switchToMinorOrMajor(chords,minorChords,1)
        }
        return chords
    }


    function getSegmentHarmony(segment) {
        //if (segment.segmentType != Segment.ChordRest) 
        //    return null;
        var aCount = 0;
        if(segment.annotations.length == 0)
            return null
        var annotation = segment.annotations[aCount];
        while (annotation) {
            if (annotation.type == Element.HARMONY)
                return annotation;
            annotation = segment.annotations[++aCount];     
        }

        return null;
    } 


    // this function is to display the possible chord and their harmony,
    // so in main function, these logic can be hidden
    function getChordsAndHarmonyText(possibleChord,chordHarmonyArray){
        var RomanNumeral = ["I", "ii", "iii", "IV", "V", "vi", "vii°"]
        var temp = [];
        for(var i = 0; i < possibleChord.length; i++){
            temp[i] = ""
            if(i == 0)
                temp[i] += ("Chord[" + RomanNumeral[i] + "] ：" + possibleChord[i] + "   \t|Traids:")
            else
                temp[i] += ("Chord[" + RomanNumeral[i] + "] ：" + possibleChord[i] + "\t|Traids:")
            for(var j = 0; j < chordHarmonyArray[i].length; j++){
                temp[i] += (" " + chordHarmonyArray[i][j])
            }
        }

        
        return temp[0] + "\n" + temp[1] + "\n" + temp[2] + "\n" + 
                temp[3] + "\n" + temp[4] + "\n" + temp[5] + "\n" + temp[6];
    }

    // function to extract notes from the score
    function extractNotes(){
        // below are the process to retrieve the notes
        var cursor = curScore.newCursor()
        var tempNotes = [[]];
        var bar = 1;
        cursor.rewind(0)
        // 2D array to store the notes in each bar tempNotes[bar][chord]
        // the algorithm to retrieve notes in each bar and put them into a 2D array
        var currentMeasure = cursor.measure
        while(currentMeasure){
            // for Element enum , use ===
            // for Segment enum , use == (capital sensitive)
            // seg is the first segment of each measure
            var seg = currentMeasure.firstSegment
            tempNotes[bar-1] = []
            // while the segment type is not end of the bar, it will go find next segment
            while (seg.segmentType != Segment.EndBarLine){
                // for each segment found, if it is a chordrest, then go see their voice
                if(seg.segmentType == Segment.ChordRest){
                    for(var voice = 0; voice < 4; voice++){
                        if(seg.elementAt(voice) && seg.elementAt(voice).type == Element.CHORD){
                            var temp = seg.elementAt(voice).notes
                            tempNotes[bar-1].push(getNoteName(temp)) 
                        }
                    }
                }
                seg = seg.nextInMeasure                        
            }
            bar++       
            currentMeasure = currentMeasure.nextMeasure        
        }
        // clear last empty bars with no notes
        var c = tempNotes.length -1
        while(tempNotes[c].length == 0){
            tempNotes.pop()
            c--
        }
        return tempNotes;
    }

    // first chord is added using this function, the first chord symbol is at after the upbeat bar
    // cursor check the first element of each bar, if it is not a chord symbol, it will go to next bar and assign
    // result in the first bar with first element is note will be assigned
    function addGuessedChords(guessedChord,nBarToStartAssign){
        curScore.startCmd();
        var cursor = curScore.newCursor();
        cursor.rewind(0);
        // skip upbeat bar --- optional 
        for(var i = 0; i < nBarToStartAssign; i++){
            cursor.nextMeasure();
        }
        for(var i = nBarToStartAssign; i < guessedChord.length; i++){
            var seg = cursor.segment
            var harmony = getSegmentHarmony(seg)
            // add first chord in the sheet music
            addChordSymbol(cursor,harmony,guessedChord[i].color,guessedChord[i].name)
            // console.log("-------------------------Bar : " + i + "-----------------------------")
            // console.log(chordsSymbol[i].name)
            cursor.nextMeasure();
        }
        curScore.endCmd();
    }

    // pass in chordNumber to addPossibleChord for that chord
    function addChordSymbol(cursor, harmony,harmonyColor, chordName){
        // var seg = cursor.segment
        // var harmony = getSegmentHarmony(seg)
        // if (harmony) { //if chord symbol exists, replace it
        //     //console.log("got harmony " + staffText + " with root: " + harmony.rootTpc + " bass: " + harmony.baseTpc);
        //     removeElement(harmony);
        //     harmony.text = chordName;
        //     harmony.color = harmonyColor;
        // }else{ //chord symbol does not exist, create it
        //     harmony = newElement(Element.HARMONY);
        //     harmony.text = chordName;
        //     harmony.color = harmonyColor;
        //     harmony.play = true;
        //     //console.log("text type:  " + staffText.type);
        //     cursor.add(harmony);
        // }
        if (harmony) { //if chord symbol exists, replace it
            //console.log("got harmony " + staffText + " with root: " + harmony.rootTpc + " bass: " + harmony.baseTpc);
            //console.log("removing chord symbol " + harmony.text)
            removeElement(harmony);
        }
        //chord symbol does not exist, create it
        harmony = newElement(Element.HARMONY);
        harmony.text = chordName;
        harmony.color = harmonyColor;
        harmony.play = true;
        //console.log("text type:  " + staffText.type);
        cursor.add(harmony);
    }

    function changeChordSymbol(name){
        curScore.startCmd()
        var cursor = curScore.newCursor();
        cursor.rewind(0)
        for(var i = 0; i < currentBarNumber; i++){
            cursor.nextMeasure();
        }
        var harmony = getSegmentHarmony(cursor.segment)
        guessedChord[currentBarNumber].name = name;
        guessedChord[currentBarNumber].color = black;
        addChordSymbol(cursor,harmony,black, guessedChord[currentBarNumber].name)
        playThisBar(cursor,harmony)
        curScore.endCmd()
    }

    // use cmd play to play this bar after changing the chord symbol
    function playThisBar(cursor,harmony){
        var seg = cursor.segment
        // console.log("cursor.segment.type = " + seg.type)
        // console.log("cursor.segment.segmentType = " + seg.segmentType)
        if(cursor.segment.segmentType == Segment.ChordRest){
            console.log("cursor.segement.elementAt(0) = " + seg.elementAt(0))
            if(seg.elementAt(0).notes){
                console.log("seg.elementAt(0).notes[0] = " + seg.elementAt(0).notes[0])
                console.log("select = " + curScore.selection.select(cursor.segment.elementAt(0).notes[0]))
            }else{
                curScore.selection.select(seg.elementAt(0))
            }
            cmd("loop-in")
            // var lastNote;
            // while(!cursor.nextMeasure()){
            //     while(cursor.next(){
            //         lastNote = 
            //     })
            // }
            curScore.selection.select(harmony) 
            cmd("play")
        }
    }
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
            cursor.nextMeasure()
            nBarsToGuess++
            guessedChord.push({index:-1 , name:"" ,color:black, tick:cursor.tick});
            
        }
        return {
            nBar: nBarsToGuess,
            cursor: cursor}
    }

    // this function use notesMatching algorithm to match with the chord harmony array
    // the result is in 2d array, array[a][b] , a = numberOfBar, b = probability/counterOfThisChordNumber,
    // exp: a[1][0] = 5, in bar 1, there are 5 notes matching with chord 0's triad note
    // exp: a[1][5] = 3, in bar 1, there are 3 notes matching with chord 5's triad note
    function notesMatching(tempNotes, chordsHarmony){
        var counter = [[]];
        // var tempChords = [[]]
        var chords = []
        var highest;
        // perform note matching to find chord that has highest match
        for(var bar = 0; bar < tempNotes.length; bar++){
            highest = 0;
            counter[bar] = [0,0,0,0,0,0,0];
            //tempChords = [];

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
            // compare with chord the highest count, to check which chords most match with the notes in bar
            // for(var i = 0; i < counter[bar].length; i++){
            //     if(counter[bar][i] == highest){
            //         tempChords[bar].push(i)
            //     }
            // }
            
                // console.log("counter[" + bar + "] : " + counter[bar] )
                // console.log(counter[bar].length)
        }
    
        return counter
    }

    // this function will return an array of indexes that has highest value
    // exp : a = [0, 5, 5, 5,1 ,3 ,4]
    // result : [1,2,3] - because index 1 2 3 has highest number (5)
    function findHighestAmong(counter){
        var highest = 0;
        var temp = [];
        var result = [];
        // find the highest 
        highest = Math.max.apply(null, counter)

        for(var i = 0; i < counter.length; i++){
            if(counter[i] == highest)
                temp.push(i);
        }
        return temp;
    }
    // ORIGINAL : 
    // this function will return an array with the most fit chord for that bar. 
    // exp: a[0] = 1; The most fitted chord for bar 0 is chord 1 (chordII)
    // IMPROVEMENT:
    // thinking of another way, which can show the probability, in that case, all the possible chords will be recorded
    // array[a][b] , a indicating the number of bar, b indicating the possible chords
    // this function returns a 2d array, chordsToBeAssigned
    function guessChordWithMode(cursor,chordsWithCounter,nBarsToGuess,chordToStart,mode){
        console.log("------------GUESSING CHORD WITH MODE :" + mode + " -----------------------")
        var lastChordNumber;
        // a array to store a object consist of name,color and tick,
        var initialGuessChords = [[]];
        var cpf = [];
        var hmc = [];
        var counter = 0;

        
        // nBarsToGuess not neccessary to be 0, because chord guess might start from bar 4
        // exp: previous bars, bar 0, bar1, bar2, bar3 all are empty bars / upbeat bars
        // default chord to start is chord I (chord 0)
        if(chordToStart == null){
            chordToStart = 0;
        }
        // if user already set the first chord
        initialGuessChords[nBarsToGuess] = []
        initialGuessChords[nBarsToGuess].push(chordToStart) ;
        guessedChord.push({index:chordToStart, name:possibleChord[chordToStart],color:black,tick:cursor.tick});
        // console.log("finalChords[" + nBarsToGuess + "].index = " + finalChord[nBarsToGuess].index)
        // console.log("finalChords[" + nBarsToGuess + "].name = " + finalChord[nBarsToGuess].name)
        // console.log("finalChords[" + nBarsToGuess + "].color = " + finalChord[nBarsToGuess].color)
        // console.log("finalChords[" + nBarsToGuess + "].tick = " + finalChord[nBarsToGuess].tick)
        lastChordNumber = chordToStart;
        nBarsToGuess++;
        //proceed to next bar
        while(nBarsToGuess < chordsWithCounter.length){
            var uncertain = false;
            // use this function to get all possible chord index in nextChord array
            initialGuessChords[nBarsToGuess] = [];
            // find CPF (chord progression formula)
            cpf = checkChordProgressionFormula(lastChordNumber,null);
            // find HMC (highest matching chords)
            hmc = findHighestAmong(chordsWithCounter[nBarsToGuess]);
            // mode == 0  || 1 
            if(mode == 0 || mode == 1){
                for(var i = 0; i < cpf.length; i++){
                    for(var j = 0; j < hmc.length; j++){
                        // every matching chord will be added into guessedChords
                        // to decide which one to be guessed is on later decision
                        // normally will go for first one, but can try rand also
                        if(cpf[i] == hmc[j]){
                            initialGuessChords[nBarsToGuess].push(cpf[i])
                        }
                    }
                }
            }
            // which mean CPF != HMC, there doesnt exist a chord matching between two algorithm
            // depending on different mode, the second chord was guess either using CPF or HMC
            if(initialGuessChords[nBarsToGuess].length == 0 && (mode == 0 || mode == 2)){
                for(var i = 0; i < cpf.length; i++){
                    if(mode == 0)
                        uncertain = true;
                    initialGuessChords[nBarsToGuess].push(cpf[i])
                }
            }
            if(initialGuessChords[nBarsToGuess].length == 0 && (mode == 1 || mode == 3)){
                    for(var i = 0; i < hmc.length; i++){
                    if(mode == 1)
                        uncertain = true;
                    initialGuessChords[nBarsToGuess].push(hmc[i])
                }  
            }
            // console.log("guessedChords[" + nBarsToGuess + "] = " + guessedChords[nBarsToGuess]);
            // Implement logic to determine which chord to choose from
            // default : always pick the first one
            var finalguessedChord;
            //finalguessedChord = guessedChord[nBarsToGuess][0]
            // or: randomized among them
            if(initialGuessChords[nBarsToGuess].length > 1){
                var rand = Math.floor(Math.random() * initialGuessChords[nBarsToGuess].length)
                finalguessedChord = initialGuessChords[nBarsToGuess][rand];
            }
            else{
                finalguessedChord = initialGuessChords[nBarsToGuess][0]
            }
            // console.log("-------------------------------BAR " + nBarsToGuess + " ---------------------------------")
            // console.log("CPF[" + nBarsToGuess + "] = " + cpf);
            // console.log("HMC[" + nBarsToGuess + "] = " + hmc);
            // console.log("InitalGuessChords[" + nBarsToGuess + "] = " + initialGuessChords[nBarsToGuess]);
            // console.log("finalguessedChord[" + nBarsToGuess + "] = " + finalguessedChord)
            cursor.nextMeasure();
            // declaring properties to store in guessedChord object
            var tempIndex = finalguessedChord;
            var tempName = possibleChord[tempIndex];
            // if uncertain use Red Chord
            if(uncertain)
                var tempColor = red;
            else
                var tempColor = black;
            var tempTick = cursor.tick;

            guessedChord.push({index: tempIndex, name: tempName, color:tempColor, tick:tempTick});            
            lastChordNumber = finalguessedChord
            nBarsToGuess++;
        }
        
        return null;
    }
    // this function aims to returns a array of next possible chord according to chord progression formula
    function checkChordProgressionFormula(lastChordNumber){
        var nextChord = [];
        switch (lastChordNumber){
            // chordI tend to go IV or V
            // 0 = I, 1 = II, 2 = III, 3 = IV, 4 = V, 5 = VI, 6 = VII
            case 0:
                nextChord = [3,4]
                break;
            case 1:
                nextChord = [4]
                break;
            case 2:
                nextChord = [5]
                break;
            case 3:
                nextChord = [4]
                break;
            case 4:
                nextChord = [0]
                break;
            case 5:
                nextChord = [1,4]
                break;
            case 6:
                nextChord = [0,2]
                break;
            default: 
                console.log("Error Chord")
                break;
        }
        return nextChord;
    }
    // function to guess chord
    function guessChord(){
        
        if (typeof curScore === 'undefined') {
            Qt.quit();
        }
        // curScore is currentScore, read only
        // startCmd() and endCmd() is neccessary for every dock plugin to make changes into sheet music
        
        // first we need to know all notes inside the score
        // after we gather all the notes we want, we can process to determine it is a minor or major key
        key = guessKey(numOfAccidentals,notes,keyOpt)
        
        // find all possible chord and their harmony in that key
        possibleChord = getAllPossibleChords(key)
        chordHarmonyArray = getPossibleChordHarmony(key, numOfAccidentals);
        chordAndHarmonyString = getChordsAndHarmonyText(possibleChord,chordHarmonyArray)
    
        // check the first note to avoid upbeat
        // console.log("\n---------------------------Chord Guess Starts-------------------------")
        var a = checkEmptyAndUpbeatBars();
        nBarsToGuess = a.nBar;
        var cursor = a.cursor;   
        // console.log("nBarToGuess = " + nBarsToGuess)     
        // console.log("added chord: " + possibleChord[lastChordNumber])
        chordWithCounter = notesMatching(notes,chordHarmonyArray);
        // assign guessedChord to guessedChord array
        guessChordWithMode(cursor,chordWithCounter,nBarsToGuess,null,mode);
        //below are the process to add harmony/chord into bars
        addGuessedChords(guessedChord,nBarsToGuess)
        return;
    }

    // for a given tick, check which bar is it, it must be the first segment in bar
    function findBar(targetTick){
        var cursor = curScore.newCursor();
        cursor.rewind(0)
        var targetTick;
        var curTick = 0;
        var i = true;
        var bar = 0;
        while(curTick != targetTick && curTick < targetTick && i){
            i = cursor.nextMeasure();
            curTick = cursor.tick
            bar++;
        }
        if(curTick > targetTick || !i){
            bar = -1;
        }
        return bar;
    }

    // change the possiblity -> new possiblity with currentChord
    function changeProbability(nBar){
        var highest = 0;
        var temp = [];
        highest = Math.max.apply(null,chordWithCounter[nBar]);
        var ppc = 100/(highest+1); // percentage per counter (ppc) = 100/highest 
        for(var i = 0; i < chordWithCounter[nBar].length; i++){
            temp.push((chordWithCounter[nBar][i] * ppc).toFixed(2))
        }
        return temp;
    }

    function changeDynamicDescription(string){
        if(string.length == 0)
            dynamicDescription = "<b>Chord Guess Plugin</b> <br><br> <i>This plugin guess chords to each bar automatically based on chord formula progression and notes analysis</i>"
        else
            dynamicDescription = string;
    }
    // onRun 
    onRun: {
        notes = extractNotes();
        probability = [];
        guessChord()
    }

    onScoreStateChanged: {
        if(state.selectionChanged){
            probability = []
            if(curScore.selection.elements.length == 0){
                console.log("NOTHING WAS SELECTED")
            }
            else if(curScore.selection.elements.length > 0){
                if(curScore.selection.elements[0].type == Element.HARMONY){
                    var firstElement = curScore.selection.elements[0]
                    var seg = firstElement.parent
                    // while(firstElemenet.parent.type != Element){}
                    currentBarNumber = findBar(seg.tick);
                } 
                else {
                    var cursor = curScore.newCursor();
                    cursor.rewind(1);
                    if(cursor.segment != null){
                        var a = cursor.segment
                        currentBarNumber = findBar(a.tick)
                    }else{
                        currentBarNumber = -1
                    }
                }

                if(currentBarNumber < 0)
                    probability = []
                else 
                    probability = changeProbability(currentBarNumber);
                
            }
            // console.log("chordwithcounter[" + currentBarNumber + "] = " + chordWithCounter[currentBarNumber])
            // console.log("probability[" + currentBarNumber + "] = " + probability)
        }
    }
    
    Rectangle{
        id: root;
        anchors.fill: parent;
        color: "lightblue";
        width: 400

        Rectangle{
            id:descriptionText;
            color:"white";
            implicitHeight:{
                if(root.height/4 >= 135)
                    return 135;
                else
                    return root.height/5;
            }
            border{
                color:"black"
                width:2
            }
            anchors{
                top: root.top; topMargin: 10
                left: root.left; leftMargin: 10;
                right: root.right; rightMargin: 10;
            }
            ScrollView {
                id: view
                clip:true
                leftPadding:10;
                topPadding:5;
                bottomPadding:10;
                rightPadding:5
                anchors{
                    fill:parent;
                }
                contentWidth:availableWidth;
                Text{
                    anchors{
                        fill:parent;
                    }
                    wrapMode:Text.WordWrap
                    text:dynamicDescription
                    Component.onCompleted:{
                        changeDynamicDescription("")
                    }
                }
            }
        }
        Rectangle{
            color: "transparent"
            id: keyText;
            height: (modeColumn.height * 2/3)
            width: descriptionText.width/2;
            MouseArea{
                hoverEnabled: true;
                anchors.fill:parent
                onEntered:{
                    changeDynamicDescription("")
                }
            }
            anchors{
                left: descriptionText.left; //leftMargin: 10;
                top: descriptionText.bottom; topMargin: 5;
            }
            clip:true;
            Text{
                wrapMode: Text.WordWrap
                anchors.fill: parent;
            font{
                bold:true;
                pixelSize:18
            }
                text: "Key of this score: " + key;
            }
        }
        

        Button{
            id: switchKeyButton;
            text: "Switch Key";  
            implicitWidth: keyText.width
            highlighted: true;
            anchors{
                left: keyText.left; // leftMargin: 10;    
                top: keyText.bottom; topMargin:5;
                bottom: modeColumn.bottom;
                // right: modeColumn.right; rightMargin: 10;
                //verticalCenter: keyText.verticalCenter;
            }

            onClicked:{
                if(keyOpt == 0)
                    keyOpt = 1
                else if(keyOpt == 1)
                    keyOpt = 0
                guessChord()
            }
        }

        ColumnLayout {
            id: modeColumn // chord guess mode
            implicitWidth: root.width/2;
            anchors{
                left: switchKeyButton.right; leftMargin: 10;
                right: descriptionText.right;
                top:descriptionText.bottom; topMargin: 10;
            }
            Text{
                font{
                    pixelSize:15;
                }
                Layout.preferredHeight:20
                text:"Chord guessing mode:";
                MouseArea{
                    anchors.fill:parent
                    hoverEnabled: true
                    id: modeDescription
                    onClicked:{changeDynamicDescription("<b>Chord <small>Guess Mode</small></b><br>\
                                        <br><i><b>HNM (Harmony note matching)</b> determine chord by matching the notes in bar and the chords' triad notes</i></small>\
                                        <br><i><b>CPF (Chord progression fomula)</b> determine chord by guessing potential chords after the previous chord</i>")}
                    ToolTip {
                        visible: parent.containsMouse
                        clip:true
                        text: "click to see details"
                        delay:1000
                    }
                } 
            }
            // ---------button 1-------------
            RadioButton {
                id:button1;
                text: qsTr("First (CPF+HNM)")
                checked:true;
                Layout.preferredHeight:20;
                onClicked:{
                    mode = 0
                    console.log("mode = " + mode)
                }
                indicator:  Rectangle {
                    width:16; height: 16; radius: 8
                    y:2 ; x:2
                    border.color: "black";
                    Rectangle {
                        width: 8
                        height: 8
                        radius: 3
                        x:parent.radius/2
                        y:parent.radius/2
                        color: "red"
                        visible:button1.checked
                    }
                }
                ToolTip {
                    visible: button1.hovered
                    clip:true
                    text: "Combine two approach, if there is no chord\nmatch both algorithm guess a chord using CPF"
                    delay:1000
                }
                contentItem: Text {
                    text: button1.text
                    opacity: button1.checked ? 1.0 : 0.6
                    color: "black"
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: button1.indicator.width
                }
            }
            //--------------button 2-----------
            RadioButton {
                text: qsTr("Second (HNM+CPF)")
                id:button2
                Layout.preferredHeight:20
                
                onClicked:{
                    mode = 1
                    console.log("mode = " + mode)
                }
                indicator:  Rectangle {
                    width:16; height: 16; radius: 8
                    y:2 ; x:2
                    border.color: "black";
                    Rectangle {
                        width: 8
                        height: 8
                        radius: 3
                        x:parent.radius/2
                        y:parent.radius/2
                        color: "red"
                        visible:button2.checked
                    }
                }
                ToolTip {
                    visible: button2.hovered
                    clip:true
                    text: "Combine two approach, if there is no chord\nmatch both algorithm guess a chord using HMC"
                    delay:1000
                }
                contentItem: Text {
                    id: button2Text
                    text: button2.text
                    opacity: button2.checked ? 1.0 : 0.6
                    color: "black"
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: button2.indicator.width
                }
            }
            //-- -------------button3 ---------------
            RadioButton {
                id:button3
                text: qsTr("Third (CPF only)")
                onClicked:{
                    mode = 2
                    console.log("mode = " + mode)
                }
                Layout.preferredHeight:20
                indicator:  Rectangle {
                    width:16; height: 16; radius: 8
                    y:2 ; x:2
                    border.color: "black";
                    Rectangle {
                        width: 8
                        height: 8
                        radius: 3
                        x:parent.radius/2
                        y:parent.radius/2
                        color: "red"
                        visible:button3.checked
                    }
                }
                ToolTip {
                    visible: button3.hovered
                    clip:true
                    text: "Guess chords using Chord Progression Formula only"
                    delay:1000
                }
                contentItem: Text {
                    text: button3.text
                    opacity: button3.checked ? 1.0 : 0.6
                    color: "black"
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: button3.indicator.width
                }
            }
            // ----------------- button 4 --------------------
            RadioButton {
                id:button4;
                text: qsTr("Fourth (HNM only)")
                onClicked:{
                    mode = 3
                    console.log("mode = " + mode)
                }
                Layout.preferredHeight:20
                indicator: Rectangle {
                    width:16; height: 16; radius: 8
                    y:2 ; x:2
                    border.color: "black";
                    Rectangle {
                        width: 8
                        height: 8
                        radius: 3
                        x:parent.radius/2
                        y:parent.radius/2
                        color: "red"
                        visible:button4.checked
                    }
                }
                ToolTip {
                    visible: button4.hovered
                    clip:true
                    text: "Guess chords using Harmony Note Matching only"
                    delay:1000
                }
                contentItem: Text {
                    id: asdb
                    text: parent.text
                    opacity: parent.checked ? 1.0 : 0.6
                    color: "black"
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: parent.indicator.width
                }
            }
        }

        
        Rectangle{
            id: possibleChordText;  
            color:"white"
            clip:true
            implicitHeight:{
                if(root.height/4 > 175)
                    return 175;
                else
                    return root.height/4
            }
            anchors{
                top: modeColumn.bottom; topMargin: 20;
                left: root.left; leftMargin: 10;
                right: root.right; rightMargin: 10;
                // bottom: possRect.top; bottomMargin: 5;
            }
            border{
                width:2
                color:black
            }
            ScrollView {
                leftPadding:10;
                topPadding:5;
                bottomPadding:10;
                rightPadding:5
                anchors{
                    fill:parent;
                }
                // contentWidth:availableWidth;
                Text{
                    anchors.fill: parent;
                    text:{"Possible chord and their triad notes:\n"+chordAndHarmonyString}                    
                }
            }
        }
        

        Rectangle{
            id: possRect // probability rectangle
            color: "black";
            implicitWidth:possGrid.implicitWidth
            implicitHeight:possGrid.implicitHeight
            anchors{
                left: descriptionText.left; leftMargin:;
                right: descriptionText.right; rightMargin:;
                bottom: guessChordButton.top ; bottomMargin:20
                top: possibleChordText.bottom; topMargin:10;
            }
            
            Grid{
                id: possGrid
                anchors{
                    fill: possRect
                }
                clip:true
                columns:2;
                rows: 8;
                spacing: 0;
                horizontalItemAlignment: Grid.AlignHCenter;
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
                        id:possEntity
                        height: possGrid.height/ possGrid.rows
                        width: possGrid.width/ possGrid.columns - border.width
                        clip:true;
                        color: "lightyellow"
                        MouseArea{
                            id:mouse2;
                            anchors.fill: parent;
                            enabled:false;
                            onPressed:{
                                parent.color = "#F9E79F"
                            }
                            onReleased:{
                                parent.color = "#F4D03F"
                            }
                            onClicked: {
                                changeChordSymbol(model.modelData)
                            }
                        }    
                        Component.onCompleted:{
                            if(model.index != 0 && model.index % 2 == 0){
                                possEntity.color = "#F4D03F"
                                //possEntity.border.color = "white"
                                mouse2.enabled = true;
                            }
                        }
                        border{
                            color:black;
                            width:2;
                        }
                        Text{
                            clip:true;
                            anchors{
                                verticalCenter: parent.verticalCenter;
                                horizontalCenter: parent.horizontalCenter;
                            }                            
                            text: model.modelData;
                            color:black;
                            font{
                                bold:true;
                                pixelSize:15;
                            }
                        }
                    }
                }              
            }
        }
        Button{
            id: guessChordButton;
            width: text.width;
            clip:true;
            text: "Guess Chord" ;
            highlighted:true
            ToolTip.visible:true;
            ToolTip.text: qsTr("SADBSBS")
            anchors{
                bottom: root.bottom;
                bottomMargin: 10;
                horizontalCenter: root.horizontalCenter;
            }
            onClicked:{
                guessChord();
            }
        }
    }
}
