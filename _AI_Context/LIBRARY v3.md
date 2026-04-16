Folder system
--------------------------------
- ONE single repository holds all the universities Notes/Date
 Repository
├─University A
	 ├─Class A
	 ├─Class B
├─University B
	 ├─Class C
	 ├─Class D

- University name -- taken from the colleges-API is the parent of the all the classes in the respective university.
- if the user changes their university in the settings, the associated classes changes accordingly.
- so, different university will have different class domains.
- Every university can have many classes and any number of same *named* classes so, each class has *unique generated ID*, to make a difference.
- Any user can  join any number of classes.
- any user can create Upto 10 classes on their name. 
- a user who created a class, can give write access to 5 other people in the [[class settings]]. total writers to the class is 6, including the creator of the class.
- Only the creator can edit the writers of the class. 
- A user can access upto one university a time. by choosing change university options in the settings.
- changing university doesn't mean loosing all the classes, if the user chooses his previous university he will get back to his previous view of the library. 

Interface UI / what user must see...
------------------------------------------------------------------------------
- Every user must have a [[Community notes v3]] pinned at the top of his classes in the library. 
- the view is clean and minimalist , with medium sized modern rounded squared clickable 

![[Pasted image 20260414173049.png|300]]

Sharing class code
-------------------------------------------
the class ID will be used in sharing the class, to help other people to join the class.  this must work via links. specifically, using the domain classes.inferalis.space/join/{class-code} <-- in a similar representation way.

