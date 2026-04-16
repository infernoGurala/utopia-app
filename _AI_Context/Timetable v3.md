the timetable must be selected by the user. 
there are 2 ways a users timetable can be asigned.
1. by selecting a timetable from the class me manually joined / created by him from selecting the list.
2. or creating a custom timetable of his own. features all edit options to customise it. 
3. the class files such as timetable will be created inside the class folder it self. since each class class have different timetables.
4. means all the configs/workflows related to the same class will be the same class folder, but only the notes files will be visible to the writer/reader mode people. -- they cannot access the code of these files of the backed logic codes.
├─Class A
	├─Notes(which is main for the student edit in app)
	 ├─Workflows/config files(only their properties will be changed by the creator of class/writer)
├─Class B
	├─Notes
	 ├─Workflows/config files

- IF the class selected by the user is empty, then show a warning, that timetable is not available for the selescted class. 

CLASS NOTIFICATION
----------------------------------------------------
- a user can choose to turn ON/OFF the notification as a toggle option.
- the class notification is timetable remainder, and it must be fetched from the class which the user has selected.
- the class notification trigger is run only once in github, that means many users have differnt timetables, so github cannot execute 100's of workflows. so, the time table is to be saved inside the app. and github only triggers the timetable feature notif, so app fetches the data and displays the correct time table. 
- the notification contains Quotes, which is, only managed by the super user, which is creator of the app. ADMIN.
