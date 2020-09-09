#!/bin/bash


# This is a quiz game Jeopardy written in bash script. The scripts
# Assumes there is at least 1 question file in ./category/
# and a path variable "festival"
#
# IMPORTANT: The session will only be saved if exit via main menu
#
# Author: Neville Loh
# Date: Aug-2020
# vesion: 1.0

# Gobal variables
SAVE_FILE=./user.save
STDERR_PATH="error.log"

winning=0
total_question_left=0
isAttempted=0


declare -a attempted
declare -a categories



#------------------------------ Helper function ------------------------------
#-------------------------------------------------
# Prompt a continue string on screen
#-------------------------------------------------
pause()
{	
	echo
	read -n 1 -s -r -p "Press any key to continue..."
	echo
}
#-------------------------------------------------
# Repopulate the vairable isAttempted
# @Input $1 The_catogiry_index
#        $2 The line number
#-------------------------------------------------
getIsAttempted()
{ 
isAttempted=${attempted[$1]:$(($2-1)):1}
}
#-------------------------------------------------
# Print the current winnings
#-------------------------------------------------
view_current_winnings()
{
	printf "\nYour current winnings is \$$winning.\n"
}

#-------------------------------------------------------------
# Checks if the selection for question value is valid
# @input $1 category_index
#        $2 the value of the question
# The function currently match to at least 2 number. This is done to 
# avoid unwanted matching in the question.
# ( will delete in the future )
#-------------------------------------------------------------
isValid()
{
	local input=$(echo "$2" | tr -cd '[0-9]._-')
	echo $input
	echo $input | grep -Eq ^*[0-9][0-9]$ || return 1
	
	if [[ $(awk -v search=$input '$0 ~ search {print}' ${categories[$1]}) -eq 0 ]] > /dev/null 2>&1
	then
		return 1
	else
		# value is good
		q_score=$input
		return 0
	fi

}

#--------------------------- End Helper function ------------------------------



#------------------------------------------------------------------------
# Printing Main menu
# print and prompt user save reply to $REPLY
#------------------------------------------------------------------------
main_menu()
{
	echo "=============================================================="
	echo "Welcome to Jeopardy!"
	echo "=============================================================="
	echo "Please select from one of the following options:"
	echo "    (p)rint question board"
	echo "    (a)sk a question"
	echo "    (v)iew current winnings"
	echo "    (r)eset game"
	echo "    e(x)it"
	echo
	read -p "Enter a selection [p/a/v/r/x]: "
}

#------------------------------------------------------------------------
# Print Question board
# print the question board according to ./categories
# 
#------------------------------------------------------------------------
print_question_board()
{
	printf "\n\nThere are $(ls ./categories | wc -l) categories.\n"
	printf "Catogries:\n"
	echo "-----------------------------------------------------------"
	local i=0
	for file in $(ls ./categories/*); do
		
		# Printing Each categories
		printf "$((i+1)). $(basename "$file") "
		
		
		
		# Printing each quesiton score of categories
		
		local line_num=1
		question_left=$(echo ${attempted[$i]} | tr -cd '0' | wc -c)
		
		# Mark category as complete if 0 question left
		if (( question_left == 0)); then
			printf "(complete)"
			
		# Print all the question score if not complete
		else
			while read line; do
				question_score=`echo $line | cut -f1 -d','`
				
				
				getIsAttempted $i $line_num
				if ! (( $isAttempted )); then
					printf "$question_score "
				fi
				line_num=$((line_num + 1))
			done < $file
		fi
		
		echo
		i=$((i + 1))
	done
	echo 
	echo "There are $total_question_left question(s) left."
	echo "-----------------------------------------------------------"
}
#------------------------------------------------------------------------
# Question selector for the quiz game
# prompt the user for the category they want to select. The function checks
# if the input is valid and if it the category still have questions left.
# If true, prompt for the question value they want to select. 
#
#------------------------------------------------------------------------
ask_a_question()
{
	while true; do
	print_question_board
	if (( total_question_left == 0 )) ; then
		game_over
		break
	fi
	
		# -------- Ask for catogry --------- 
		while true; do

			read -p "Choose a category(enter a number): " cat_index
			if (( $cat_index > 0 )) 2> $STDERR_PATH && (( $cat_index <= ${#categories[*]} )) ;then
				cat_index=$((cat_index - 1))
				
				local question_left=$(echo ${attempted[$cat_index]} | tr -cd '0' | wc -c)
		
				# Mark category as complete if 0 question left
				if (( question_left == 0)); then
					printf "\nThis category has no more question left.\n"
					echo "Try select another category?"
					pause
				else
					break 
				fi
			else
				printf "\nPlease enter a valid catogry number.\n\n"
			fi
			
		done

		
		#---------- Ask for number ---------- 
		while true; do		
			read -p "Choose a value in [$(basename ${categories[$cat_index]})] : " q_score
			
			if isValid $cat_index $q_score 2> /dev/null;then
				line_num=$(awk -v search=$q_score '$0 ~ search{print NR; exit}' $file) 2> $STDERR_PATH
				
				# Checking if the question is atempted before	
				getIsAttempted $cat_index $line_num
				if (( $isAttempted )); then
					printf "The question has already been attempted.\n\n"
				else
					question
					total_question_left=$((total_question_left-1))
					pause
					break 2
				fi
			else
				printf "Cannot find value associating to the cateogry. Try something else? \n\n"
			fi	
		done

	done
	
}
#------------------------------------------------------------------------
# Ask one question for user
# @require global variable
# 	cat_index
#	q_score
#
# The function asked the user question by printing and reading it out
# using -festival. Then get the solution from the user. The golbal score,
# winning, is updated after each question. The question is then marked as
# attempted using a attmpted string. e.g. "00000" to "10000". where 0
# represent not attempted, 1 represent attmpted.
#
#------------------------------------------------------------------------
question()
{
	# get lines and all the variables
	line=$(awk -v search=$q_score '$0 ~ search{print}' ${categories[$cat_index]})
	line_num=$(awk -v search=$q_score '$0 ~ search{print NR; exit}' ${categories[$cat_index]})
	q_score=`echo $line | cut -f1 -d','`
	question=`echo $line | cut -f2 -d','`
	solution=`echo $line | cut -f3 -d','`
	
	
	printf "\n-----------------------------------------------------------------------\n\n"
	echo "     " $question
	printf "\n-----------------------------------------------------------------------\n\n"
	
	# Read out the question using festival
	echo $question | festival --tts 2> $STDERR_PATH 1> /dev/null
	
	# user answering the quesiton
	read -p "Your answer: " user_ans
	
	# strip all special chars and lowerit
	user_ans=$(echo "$user_ans" | tr -cd '[:alnum:]._-' | tr '[:upper:]' '[:lower:]')
	printf "\n\n"
	
	if [ $user_ans == $(echo "$solution" | tr '[:upper:]' '[:lower:]') ] 2> $STDERR_PATH ; then
		echo "Correct."
		echo "Correct" | festival --tts 2> $STDERR_PATH 1> /dev/null
		winning=$((winning + q_score))
	else
		echo "Incorrect. The answer is $solution."
		echo "Incorrect The answer is $solution" | festival --tts 2> $STDERR_PATH 1> /dev/null
		winning=$((winning - q_score))
	fi
	echo
	view_current_winnings
	
	# Saving the result
	# returns a string '11111' for example
	log=${attempted[$cat_index]} 
	# changes the val_index to 0
	attempted[$cat_index]="${log:0:$line_num-1}1${log:$(($line_num))}" 
}

#------------------------------------------------------------------------
# initialize game over sequence
# Prompt user to see if they want to reset the game.
# If not, return to main menu.
#------------------------------------------------------------------------
game_over()
{
	echo
	echo "There are no more remaining questions."
	pause
	printf "\n\n            Your final winning is \$$winning.\n\n"
	echo   "---------------------------------------------------"
	printf "|              Thank you for playing!              |\n"
	echo   "---------------------------------------------------"
	pause
	read -p "Do you wish to reset the game?(y/n) : " wantReset
	case $wantReset in
		# Print Question Board
		[Yy]|[Yy][Ee][Ss])
			reset_status
				
			printf "\n\nThe game have been reset."
			pause
		;;
		*)
			printf "\nYour save file have been kept. You can always reset the game in the main menu\n\n"
		;;
	esac
	printf "\n\nreturning to main menu..."
	pause

}

#------------------------------------------------------------------------
# function to save the file. The current save format 
# is 
# line 1, player_wining(line1)
# line 2, attempt_string_of_categories_2
# line 3, attempt_string_of_categories_3
# ....
# line n attempt_string_of_categories_n
#
#  Where the attempt_string is in a form of 0 and 1s
#  0 represent unatempted quetsion and 
#  1 represent attempted question.
#  
#  *The length of the string depends on the number of question in each 
#  category
#
#  *The position of each 0 and 1 represnet the order of the lines in 
#   the category files.
#
#------------------------------------------------------------------------
save()
{
	#Saving current attempt and winning
	exec 3<> ./save.temp
	echo $winning >&3
	for ((i=0; i < ${#categories[*]}; i=i+1)) ; do
	echo ${attempted[i]} >&3
	done
	exec 3>&-
	
	# Replacing the file
	cp -f ./save.temp $SAVE_FILE
	rm save.temp
}

#------------------------------------------------------------------------
# load the current save file
# Expected present of $SAVE_FILE in global variables
# return stderr if not present.
#------------------------------------------------------------------------
load()
{
	# Loading first line as score
	winning=$(head -n 1 $SAVE_FILE)
	
	# Load rest of the line as question attempted
	local i=0
	while IFS= read -r line; do
			attempted[$i]=$line
			count=$(echo $line | tr -cd '0' | wc -c)
			total_question_left=$((total_question_left+count))
			i=$((i + 1))
		done < <(tail -n "+2" $SAVE_FILE)
}

#------------------------------------------------------------------------
# reset the user progress
# set global winning to 0
# Set all atempted string to 00000 (len depends on the number of question
#------------------------------------------------------------------------
reset_status()
{
	winning=0
	question_numbers=5
	local s=$(printf "%-${question_numbers}s" "0")
	
	for ((i=0; i < ${#categories[*]}; i=i+1)) ; do
		# create questions number many of zeros
		attempted[$i]=$(echo "${s// /0}")
		count=$(echo ${attempted[$i]} | tr -cd '0' | wc -c)
		total_question_left=$((total_question_left+count))
	done 
}

#------------------------------------------------------------------------
# initialize the game
# load all categories and if save file exist, load save file.
# if not, create new save file.
#------------------------------------------------------------------------
init(){
	local i=0
	for file in $(ls ./categories/*); do
		categories[i]=$file
		i=$((i + 1))
	done
	
	if test -f "$SAVE_FILE" ; then
		echo "Save file found. Loading $SAVE_FILE..."
		load
	else
		reset_status
	fi
	
}
#------------------------------------------------------------------------
# Game Loop
# Main function of the program
# loop through various mode until user promt to exit
#------------------------------------------------------------------------
Game(){
init
while true; do
	main_menu
	case $REPLY in
		# Print Question Board
		p|P)
			print_question_board
			pause
		;;
		
		# Ask a question
		a|A)
			ask_a_question
		;;
		
		# view current winnings
		v|V)
			view_current_winnings
			pause
		;;
		
		# Reset game
		r|R)
			read -p "Do you really wish to reset the game? (y/n): " wantReset
			case $wantReset in
			 	[Yy]|[yY][eE][sS])
			 		reset_status	
					printf "\n\nThe game have been reset."
					pause
			 	;;
			 	*)
			 		printf "\nReturning to main menu"
					pause
			 	;;
			esac
		;;
		
		# Exit the game
		x|X)
			save
			printf "\nYou progress have been saved. "
			pause
			exit 1
		;;
		*)
			echo "The command is invalid. Try something else again? [p/a/v/r/x]"
			pause
		;;
	esac
	echo ""
done
}

Game



