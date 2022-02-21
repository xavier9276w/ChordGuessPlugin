import MuseScore 3.0
import QtQuick 2.1
import QtQuick.Layouts 1.0
import QtQuick.Controls 1.4
import QtQuick.Dialogs 1.0
import Qt.labs.settings 1.0

MuseScore {
    version:  "3.0";
	description: "Guess chord based on the notes bar by bar, based on some logic.";
	menuPath: "Plugins.ChordGuessV1";
    pluginType: "dock";
    requiresScore: true;
    dockArea: "left";
    implicitWidth: 400;
    implicitHeight: 3000;

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
    property var a : "ASBSD";
    property var mode: 0;
    property var notes;
    property var key;
    property var possibleChord;
    property var chordHarmonyArray;
    property var chordAndHarmonyString;
    property var guessedChord;
    property var chordWithCounter;
    property var chordWithProgression;
    property var nBarsToGuess;
    property var possibility; 
    property var currentBarNumber: 0;
    // nameNote function is used to identify all the notes present in the score
    // tpc is tonal pitch class, each represent a pitch such as (14 = C)
    // the notes pass in is a list
    // tpc	name	tpc	name	tpc	name	tpc	name	tpc	name
    // -1	F♭♭	    6	F♭	    13	F	    20	F♯	    27	F♯♯
    // 0	C♭♭	    7	C♭	    14	C	    21	C♯	    28	C♯♯
    // 1	G♭♭	    8	G♭	    15	G	    22	G♯	    29	G♯♯
    // 2	D♭♭	    9	D♭	    16	D	    23	D♯	    30	D♯♯
    // 3	A♭♭	    10	A♭	    17	A	    24	A♯	    31	A♯♯
    // 4	E♭♭	    11	E♭	    18	E	    25	E♯	    32	E♯♯
    // 5	B♭♭	    12	B♭	    19	B	    26	B♯	    33	B♯♯
    function getNoteName (tempNotes) {
        // tpc_str is the array of tpc name in order of tpc table above
        // 0 = C flat flat, 14 = C etc.
        var tpc_str = ["C♭♭","G♭♭","D♭♭","A♭♭","E♭♭","B♭♭",
                "F♭","C♭","G♭","D♭","A♭","E♭","B♭","F","C","G","D","A","E","B","F♯","C♯","G♯","D♯","A♯","E♯","B♯",
                "F♯♯","C♯♯","G♯♯","D♯♯","A♯♯","E♯♯","B♯♯","F♭♭"]; //tpc -1 is at number 34 (last item).
        
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
    
    // findKey function is used to find the key of the score based on number of accidentals (♯/♭)
    // positive(+) number indicates n of sharps, negative(-) number indicate n of flats
    function getKey(numOfAccidentals){
        var key = "";
        // possibleChordsInKey shows all possible chords in this key
        var possibleChordsInKey = []
        switch(numOfAccidentals){
            case -7: key = "C♭ Major/A♭ minor"; break;
            case -6: key = "G♭ Major/E♭ minor"; break;
            case -5: key = "D♭ Major/B♭ minor"; break;
            case -4: key = "A♭ Major/F minor"; break;
            case -3: key = "E♭ Major/C minor"; break;
            case -2: key = "B♭ Major/G minor"; break;
            case -1: key = "F Major/D minor"; break;
            case 0: key = "C Major/A minor"; break;
            case 1: key = "G Major/E minor"; break;
            case 2: key = "D Major/B minor"; break;
            case 3: key = "A Major/F♯ minor"; break;
            case 4: key = "E Major/C♯ minor"; break;
            case 5: key = "B Major/G♯ minor"; break;
            case 6: key = "F♯ Major/D♯ minor"; break;
            case 7: key = "C♯ Major/A♯ minor"; break;
            default: return "Undefined ??/ no key?"; // this should never prompt
        }
        return key;
    }

    // function to guess key
    function guessKey(numOfAccidentals,tempNotes){
        var lastNote = tempNotes[tempNotes.length-1][tempNotes[tempNotes.length-1].length-1];
        var tempKey = getKey(numOfAccidentals)
        // check the last note and key
        if(tempKey.includes(lastNote)){
            // if the key is same with the last note, then it is that key
            if(tempKey.startsWith(lastNote))
                tempKey = tempKey.slice(0, tempKey.indexOf("/"))
            else
                tempKey = tempKey.slice(tempKey.indexOf("/")+1 , tempKey.length)
        }
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
            var accidentalMark = "♯";
        }else {
            var accidentalSequence =  ["B", "E", "A","D","G","C","F"]
            var accidentalMark = "♭";
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
        if("C♭ Major/A♭ minor".includes(key)) chords = ["Cb", "D♭m", "E♭m", "F♭" , "G♭" , "A♭m", "B♭dim"];
        if("G♭ Major/E♭ minor".includes(key)) chords = ["Gb", "A♭m", "B♭m", "C♭" , "D♭" , "E♭m", "Fdim" ];
        if("D♭ Major/B♭ minor".includes(key)) chords = ["D♭", "E♭m", "Fm" , "G♭" , "A♭" , "B♭m", "Cdim" ];
        if("A♭ Major/F minor".includes(key))  chords = ["A♭", "B♭m", "Cm" , "D♭" , "E♭" , "Fm", "Gdim"  ];
        if("E♭ Major/C minor".includes(key))  chords = ["E♭", "Fm" , "Gm" , "A♭" , "B♭" , "Cm", "Ddim"  ];
        if("B♭ Major/G minor".includes(key))  chords = ["B♭", "Cm" , "Dm" , "E♭" , "F"  , "Gm", "Adim"  ];
        if("F Major/D minor".includes(key))   chords = ["F" , "Gm" , "Am" , "B♭" , "C" , "Dm" , "Em"    ];
    
        if("C Major/A minor".includes(key))   chords = ["C",  "Dm", "Em", "F"  , "G", "Am", "Bdim"];

        if("G Major/E minor".includes(key))   chords = ["G" , "Am" , "Bm" , "C" , "D" , "Em" , "F♯dim"];
        if("D Major/B minor".includes(key))   chords = ["D" , "Em" , "F#m", "G" , "A" , "Bm" , "C♯dim"];
        if("A Major/F♯ minor".includes(key))  chords = ["A" , "Bm" , "C♯m", "D" , "E" , "F♯m", "G♯dim"];
        if("E Major/C♯ minor".includes(key))  chords = ["E" , "F♯m", "G♯m", "A" , "B" , "C♯m", "D♯dim"];
        if("B Major/G♯ minor".includes(key))  chords = ["B" , "C♯m", "D♯m", "E" , "F♯", "G♯m", "A♯dim"];
        if("F♯ Major/D♯ minor".includes(key)) chords = ["F♯", "G♯m", "A♯m", "B" , "C♯", "D♯m", "E♯dim"];
        if("C♯ Major/A♯ minor".includes(key)) chords = ["C♯", "D♯m", "E♯m", "F♯", "G♯", "A♯m", "B♯dim"];

        if(isMinor){
            chords = switchToMinorOrMajor(chords,minorChords,1)
        }
        return chords
    }

 
    function getSegmentHarmony(segment) {
        //if (segment.segmentType != Segment.ChordRest) 
        //    return null;
        var aCount = 0;
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
    function addGuessedChords(chordsSymbol,nBarToStartAssign){
        curScore.startCmd();
        var tempBar = 0
        var cursor = curScore.newCursor();
        cursor.rewind(0);
        // skip upbeat bar --- optional 
        for(var i = 0; i < nBarToStartAssign; i++){
            cursor.nextMeasure();
        }
        for(var i = 0; i < chordsSymbol.length; i ++){
            var seg = cursor.segment
            var harmony = getSegmentHarmony(seg)
            // add first chord in the sheet music
            // console.log("-----------------------Bar: " + (bar+1) + "-------------------------------")
            addChordSymbol(cursor,harmony,black,chordsSymbol[i])
            cursor.nextMeasure();
        }
        curScore.endCmd();
    }

 // pass in chordNumber to addPossibleChord for that chord
    function addChordSymbol(cursor, harmony,harmonyColor, chordNumber){
        // var seg = cursor.segment
        // var harmony = getSegmentHarmony(seg)
        if (harmony) { //if chord symbol exists, replace it
            //console.log("got harmony " + staffText + " with root: " + harmony.rootTpc + " bass: " + harmony.baseTpc);
            harmony.text = possibleChord[chordNumber];
            harmony.color = harmonyColor;
        }else{ //chord symbol does not exist, create it
            harmony = newElement(Element.HARMONY);
            harmony.text = possibleChord[chordNumber];
            harmony.color = harmonyColor;
            //console.log("text type:  " + staffText.type);
            cursor.add(harmony);
        }
    }
    function checkEmptyAndUpbeatBars(){
        var nBarsToGuess = 0;
        var cursor = curScore.newCursor();
        cursor.rewind(0);
        // skip upbeat bar --- optional 
        while(cursor.element.name != "Chord"){
            cursor.nextMeasure()
            nBarsToGuess++
        }
        return nBarsToGuess;
    }

    // this function use notesMatching algorithm to match with the chord harmony array
    // the result is in 2d array, array[a][b] , a = numberOfBar, b = possibility/counterOfThisChordNumber,
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
            
            console.log("counter[" + bar + "] : " + counter[bar] )
            console.log(counter[bar].length)
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
    // thinking of another way, which can show the possibility, in that case, all the possible chords will be recorded
    // array[a][b] , a indicating the number of bar, b indicating the possible chords
    // this function returns a 2d array, chordsToBeAssigned
    function guessChordWithMode(chordsWithCounter,nBarsToGuess,chordToStart,mode){
        var seg;
        var harmony;
        var lastChordNumber;
        var guessedChords = [[]];
        var finalChord = [];
        var cpf = [];
        var hmc = [];
        // nBarsToGuess not neccessary to be 0, because chord guess might start from bar 4
        // exp: previous bars, bar 0, bar1, bar2, bar3 all are empty bars / upbeat bars
        // default chord to start is chord I (chord 0)
        if(chordToStart == null){
            chordToStart = 0;
        }
        // if user already set the first chord
        guessedChords[nBarsToGuess].push(chordToStart) ;
        // console.log("mode = " + mode)
        // console.log("chordtostart = " + chordToStart)
        // console.log("guessedChords[" + nBarsToGuess + "] = " + guessedChords[nBarsToGuess][0])
        finalChord.push(chordToStart);
        lastChordNumber = chordToStart;
        nBarsToGuess++;
        //proceed to next bar
        while(nBarsToGuess < chordsWithCounter.length){
            // use this function to get all possible chord index in nextChord array
            guessedChords[nBarsToGuess] = [];
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
                            guessedChords[nBarsToGuess].push(cpf[i])
                        }
                    }
                }
            }
            // which mean CPF != HMC, there doesnt exist a chord matching between two algorithm
            // depending on different mode, the second chord was guess either using CPF or HMC
            if(guessedChords[nBarsToGuess].length == 0 && (mode == 0 || mode == 2)){
                for(var i = 0; i < cpf.length; i++){
                    guessedChords[nBarsToGuess].push(cpf[i])
                }
            }
            if(guessedChords[nBarsToGuess].length == 0 && (mode == 1 || mode == 3)){
                    for(var i = 0; i < hmc.length; i++){
                    guessedChords[nBarsToGuess].push(hmc[i])
                }  
            }
            console.log("guessedChords[" + nBarsToGuess + "] = " + guessedChords[nBarsToGuess]);
            // Implement logic to determine which chord to choose from
            // default : always pick the first one
            var finalguessedChords = guessedChords[nBarsToGuess][0];
            finalChord.push(finalguessedChords)
            lastChordNumber = finalguessedChords
            // or: randomized among them
            nBarsToGuess++;
        }
        
        return finalChord;
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

        key = guessKey(numOfAccidentals,notes)

        // find all possible chord and their harmony in that key
        possibleChord = getAllPossibleChords(key)
        chordHarmonyArray = getPossibleChordHarmony(key, numOfAccidentals);
        chordAndHarmonyString = getChordsAndHarmonyText(possibleChord,chordHarmonyArray)
    
        // check the first note to avoid upbeat
        // console.log("\n---------------------------Chord Guess Starts-------------------------")
        nBarsToGuess = checkEmptyAndUpbeatBars();
        console.log("BAR = " + nBarsToGuess)
        // console.log("added chord: " + possibleChord[lastChordNumber])
        chordWithCounter = notesMatching(notes,chordHarmonyArray);
        guessedChord = guessChordWithMode(chordWithCounter,nBarsToGuess,null,mode);
        //below are the process to add harmony/chord into bars
        addGuessedChords(guessedChord,nBarsToGuess)
        return;
    }

    function guessChordWithKey(key){
        key = key;
        chordWithCounter = notesMatching(notes,chordHarmonyArray);
        guessedChord = guessChordWithMode(chordWithCounter,nBarsToGuess,null,mode);
        addGuessedChords(guessedChord,nBarsToGuess)
    }

    function findBar(){
        var cursor = curScore.newCursor();
        var cursor2 = curScore.newCursor();
        cursor2.rewind(0);
        var ab1;
        var ab2 = 0;
        var i = true;
        var bar = 0;
        // make cursor rewind to selection
        cursor.rewind(1)
        ab1 = cursor.tick;
        while(ab2 != ab1 && ab2 < ab1 && i){
            i = cursor2.nextMeasure();
            ab2 = cursor2.tick
            bar++;
        }
        if(ab2 > ab1 || !i){
            bar = 0;
            console.log("invalid selection, wrong")
        }
        return bar;
    }

    function changePossibility(nBar){
        var highest = 0;
        var temp = [];
        highest = Math.max.apply(null,chordWithCounter[nBar]);
        var ppc = 100/(highest+1); // percentage per counter (ppc) = 100/highest 
        for(var i = 0; i < chordWithCounter[nBar].length; i++){
            temp.push((chordWithCounter[nBar][i] * ppc).toFixed(2))
        }
        return temp;
    }
    // onRun 
    onRun: {
        notes = extractNotes();
        possibility = [];
        guessChord()
    }

    onScoreStateChanged: {
        if(state.selectionChanged){
            currentBarNumber = findBar();
            console.log("chordwithcounter[" + currentBarNumber + "] = " + chordWithCounter[currentBarNumber])
            possibility = changePossibility(currentBarNumber);
            console.log("possibility[" + currentBarNumber + "] = " + possibility)
        }
    }

    Rectangle{
        id: root;
        color: "lightblue";
        width:parent.width;
        height:parent.height;
        anchors.fill: parent;
        TextArea{
            id: descriptionText;
            readOnly : true;
            height: 110;
            anchors{
                top: root.top; topMargin: 10
                left: root.left; leftMargin: 10;
                right: root.right; rightMargin: 10;
            }
            font{
                bold:true;
            }
            text: "ChordGuess Plugin\n\nThis plugin guess chords to each bar automatically based on chord formula progression and notes analysis";
        } 
    
        Text{
            id: keyText;
            height: 30;
            width: descriptionText.width/2 ;
            wrapMode: Text.WordWrap
            font{
                bold:true;
                pixelSize:height/2
            }
            anchors{
                left: descriptionText.left; //leftMargin: 10;
                top: descriptionText.bottom; topMargin: 5;
            }
            text: "Key of this score: " + key;
        }
        
        
        Button{
            id: switchKeyButton;
            text: "Switch Key";  
            height: 35;
            
            implicitWidth: descriptionText.width/2
            anchors{
                left: keyText.right; leftMargin: 10;    
                top: keyText.top;
                right: root.right; rightMargin: 10;
                //verticalCenter: keyText.verticalCenter;
            }
            onClicked:{
                switchKey();
            }
        }

        
        TextArea{
            id: possibleChordText;  
            readOnly : true;
            text:{"Possible chord and their triad notes:\n"+chordAndHarmonyString}
            height:170;
            anchors{
                top: keyText.bottom; topMargin: 20;
                left: root.left; leftMargin: 10;
                right: root.right; rightMargin: 10;
                bottom: possibilityRectangle.top; bottomMargin: 5;
            }
                
        }

        Rectangle{
            id: possRect // possibility rectangle
            color: "black";
            implicitWidth:possGrid.implicitWidth
            implicitHeight:possGrid.implicitHeight
        
            anchors{
                left: descriptionText.left; leftMargin:;
                right: descriptionText.right; rightMargin:;
                bottom: guessChordButton.top ; bottomMargin:20
                top: possibleChordText.bottom; topMargin:10;
            }
            
            // Text{
            //     id:possText
            //     width: possGrid.implicitWidth;
            //     height: 20
            //     anchors{
            //         top:possRect.top;topMargin: 10;
            //         left: possRect.left;leftMargin: 20;
            //         right:possRect.right;rightMargin: 20;
            //         bottom: possGrid.left;bottomMargin: 10;
            //     }
            //     text:"Select any bar or first note in that bar to see the possibility of each chords."
            // }
            Grid{
                id: possGrid
                anchors{
                    leftMargin: 5;
                    topMargin: 5;
                    rightMargin: 5;
                    bottomMargin: 5;
                    fill: possRect
                }
                clip:true
                columns:2;
                rows: 8;
                spacing: 0;
                horizontalItemAlignment: Grid.AlignHCenter;
                Repeater{
                    id: gridRepeater
                    model: ["CHORD NAME" , "POSSIBILITY", ""+ possibleChord[0] , 
                            ""+ possibility[0] + "%", ""+ possibleChord[1] , 
                            ""+ possibility[1] + "%", ""+ possibleChord[2] , 
                            ""+ possibility[2] + "%", ""+ possibleChord[3] ,
                            ""+ possibility[3] + "%", ""+ possibleChord[4] , 
                            ""+ possibility[4] + "%", ""+ possibleChord[5] , 
                            ""+ possibility[5] + "%", ""+possibleChord[6] , 
                            ""+ possibility[6] + "%"]
                    Rectangle{
                        height: possGrid.height/ possGrid.rows
                        width: possGrid.width/ possGrid.columns - border.width
                        clip:true;
                        color: "lightyellow"
                        anchors.margins:0
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

                 
                // Text{id: "r1c1"; text:"Chord"; font{bold:true; pixelSize:20;} width:parent.width/2; clip: true;  }
                // Text{id: "r1c2"; text:"Possibility"; font{bold:true; pixelSize:20;} width:parent.width/2;horizontalAlignment:Text.AlignHCenter;clip: true;  }
                // Text{id: "r2c1"; text: ""+ possibleChord[0]; width:parent.width/2}
                // Text{id: "r2c2"; text: ""+ possibility[0] + "%"; }
                // Text{id: "r3c1"; text: ""+ possibleChord[1]; width:parent.width/2}
                // Text{id: "r3c2"; text: ""+ possibility[1] + "%"}
                // Text{id: "r4c1"; text: ""+ possibleChord[2];  width:parent.width/2}
                // Text{id: "r4c2"; text: ""+ possibility[2] + "%";}
                // Text{id: "r5c1"; text: ""+ possibleChord[3]; width:parent.width/2}
                // Text{id: "r5c2"; text: ""+ possibility[3] + "%"}
                // Text{id: "r6c1"; text: ""+ possibleChord[4]; width:parent.width/2}
                // Text{id: "r6c2"; text: ""+ possibility[4] + "%"}
                // Text{id: "r7c1"; text: ""+ possibleChord[5]; width:parent.width/2}
                // Text{id: "r7c2"; text: ""+ possibility[5] + "%"}
                // Text{id: "r8c1"; text: ""+ possibleChord[6]; width:parent.width/2}
                // Text{id: "r8c2"; text: ""+ possibility[6] + "%"}
                // Repeater{
                //     model:[ text:"SBSDB", "Possibility", possibleChord[0], possibleChord[1]]
                //     Text{
                //         width:parent.width/2;
                //         text: model.modelData
                //     }
                // }
                
                
            }
        }
        Button{
            id: guessChordButton;
            width: text.width;
            clip:true;
            text: "Guess Chord" ;
            anchors{
                bottom: root.bottom;
                bottomMargin: 10;
                horizontalCenter: root.horizontalCenter;
            }
            onClicked:{
                guessChordWithKey(key);
                
            }
        }
    }
}
