
----Drop database
--if exists
--(
--	select *
--	from sysdatabases
--	where [name] = 'BikeRentalDatabase'
--)
--drop database BikeRentalDatabase
--go

----Create database
--create database BikeRentalDatabase
--go

--Drop all tables from database
if exists
( 
	select [name]
	from BikeRentalDatabase.dbo.sysobjects
	where [name] = 'Sessions'
)
drop table dbo.Sessions
go

if exists
( 
	select [name]
	from BikeRentalDatabase.dbo.sysobjects
	where [name] = 'Riders'
)
drop table dbo.Riders
go

if exists
( 
	select [name]
	from BikeRentalDatabase.dbo.sysobjects
	where [name] = 'Class'
)
drop table dbo.Class
go

if exists
( 
	select [name]
	from BikeRentalDatabase.dbo.sysobjects
	where [name] = 'Bikes'
)
drop table dbo.Bikes
go

--Create all tables for database
create table dbo.Class
(
	ClassID nchar(6) not null,
	ClassDescription nvarchar(51) not null,

	constraint PK_Class_ClassID primary key (ClassID)
)
go

create table dbo.Riders
(
	RiderID int identity (10, 1) not null 
		constraint PK_Riders_RidersID primary key,
	[Name] nvarchar(50) not null
		constraint CHK_Riders_Name check (len([Name]) > 4),
	ClassID nchar(6) null,

	constraint FK_Riders_Class foreign key (ClassID)
			references Class(ClassID) on delete no action
)
go

create table dbo.Bikes
(
	BikeID nchar(6) not null 
		constraint PK_Bikes_BikeID primary key
		constraint CHK_Bikes_BikeID check (BikeID LIKE '[0-9][0-9][0-9][HYS]-[AP]'),
	StableDate date not null default getdate()
)
go

create table dbo.[Sessions]
(
	SessionDate datetime not null 
		constraint CHK_Sessions_SessionDate check (SessionDate > '2017-09-01'),
	RiderID int not null,
	BikeID nchar(6) not null,
	Laps int null,

	constraint PK_Sessions_SessionsDate_RiderID_BikeID primary key(SessionDate, RiderID, BikeID),
	index IDX_Sessions_RiderID_BikeID (RiderID, BikeID)
)
go

--Alter tables to new specifications
alter table [Sessions] add constraint CHK_Sessions_Laps check (Laps >= 10)
go

alter table [Sessions] add constraint FK_Sessions_Riders foreign key (RiderID)
							   references Riders(RiderID) on delete no action
go

alter table [Sessions] add constraint FK_Sessions_Bikes foreign key (BikeID)
							   references Bikes(BikeID) on delete no action
go

--Create stored procedures for databse
if EXISTS (select * 
		   from sysobjects
		   where [name] = 'PopulateClass')
   drop procedure PopulateClass
go

----------------------------------------------------
--Stored Procedure : Populate Class
--Inputs : nvarchar(OUT)
--Outputs : int
--Description: Populate Class with pre-determined Classes
----------------------------------------------------
create procedure PopulateClass
@ErrorMessage as nvarchar(MAX) out
as
	insert into BikeRentalDatabase.dbo.Class(ClassID, ClassDescription)
	values ('moto_3', 'Default Classis, custom 125cc engine'),
		   ('moto_2', 'Common 600cc engine and electronics, Custom Chassis'),
		   ('motogp', '1000cc Full Factory Spec, common electronics')

	set @ErrorMessage = 'SPPopulateClass:OK'
	return 0
go

if EXISTS (select * 
		   from sysobjects
		   where [name] = 'PopulateBikes')
   drop procedure PopulateBikes
go

----------------------------------------------------
--Stored Procedure : Populate Bikes
--Inputs : nvarchar(OUT)
--Outputs : int
--Description: Populate Bikes with pre-determined Bikes
----------------------------------------------------
create procedure PopulateBikes
@ErrorMessage as nvarchar(MAX) out
as
	declare @countIndex int = 0
	declare @countBrand int = 0
	declare @countTime int = 0
	declare @currentBike nvarchar(3)
	declare @currentBrand nvarchar(1)
	declare @currentTime nvarchar(1)

	while @countIndex < 20
	begin
		if @countIndex >= 10
			set @currentBike = '0' + CONVERT(nvarchar(2), @countIndex)
		else
			set @currentBike = '00' + CONVERT(nvarchar(1), @countIndex)

		set @countBrand = 0
		set @countIndex = @countIndex + 1

		while @countBrand < 3
		begin
			if @countBrand = 0
				set @currentBrand = 'H'
			if @countBrand = 1
				set @currentBrand = 'Y'
			if @countBrand = 2
				set @currentBrand = 'S'

			set @countTime = 0
			set @countBrand = @countBrand + 1

			while @countTime < 2
			begin
				if @countTime = 0
					set @currentTime = 'A'
				if @countTime = 1
					set @currentTime = 'P'

				set @countTime = @countTime + 1

				declare @BikeID as nchar(6) = @currentBike + @currentBrand + '-' + @currentTime

				if EXISTS (select *
						   from tchung13.dbo.Bikes
						   where BikeID = @BikeID)
					begin
						set @ErrorMessage = 'SPPopulateBikes:Error - BikeID already exists'
						return -1
					end

				insert into BikeRentalDatabase.dbo.Bikes (BikeID)
				values (@currentBike + @currentBrand + '-' + @currentTime)
			end
		end
	end

	set @ErrorMessage = 'SPPopulateBikes:OK'
	return 0
go

if EXISTS (select * 
		   from sysobjects
		   where [name] = 'AddRider')
   drop procedure AddRider
go

----------------------------------------------------
--Stored Procedure : Add Rider
--Inputs : nvarchar, nchar, nvarchar(OUT)
--Outputs : int
--Description: Take supplied Name and ClassID, create Rider
----------------------------------------------------
create procedure AddRider
@Name as nvarchar(50),
@ClassID as nchar(6),
@ErrorMessage as nvarchar(MAX) out
as
	if @Name IS NULL
		begin
			set @ErrorMessage = 'SPAddRider:Error - Name can''t be NULL'
			return -1
		end
	if NOT EXISTS(select * 
			  from BikeRentalDatabase.dbo.Class
			  where ClassID = @ClassID)
		begin
			set @ErrorMessage = 'SPAddRider:Error - ClassID [' + @ClassID + '] does not exists'
			return -2
		end
	
	insert into BikeRentalDatabase.dbo.Riders (Name, ClassID)
	values (@Name, @ClassID)

	set @ErrorMessage = 'SPAddRider:OK'
	return @@IDENTITY
go

if EXISTS (select * 
		   from sysobjects
		   where [name] = 'RemoveRider')
   drop procedure RemoveRider
go

----------------------------------------------------
--Stored Procedure : Remove Rider
--Inputs : int, bit, nvarchar(OUT)
--Outputs : int
--Description: Delete supplied RiderID, if Force is true, delete sessions that RiderID is included
----------------------------------------------------
create procedure RemoveRider
@RiderID as int,
@Force as bit = 0,
@ErrorMessage as nvarchar(MAX) out
as
	if @RiderID IS NULL
		begin
			set @ErrorMessage = 'SPRemoveRider:Error - RiderID can''t be NULL'
			return -1
		end
	if NOT EXISTS(select * 
			  from BikeRentalDatabase.dbo.Riders
			  where RiderID = @RiderID)
		begin
			set @ErrorMessage = 'SPRemoveRider:Error - RiderID [' + CONVERT(nvarchar(10), @RiderID) + '] does not exists'
			return -2
		end
	if @Force = 0
		begin
			if EXISTS(select *
					  from BikeRentalDatabase.dbo.Sessions
					  where RiderID = @RiderID)
				begin
					set @ErrorMessage = 'SPRemoveRider:Error - RiderID [' + CONVERT(nvarchar(10), @RiderID) + '] exists in Sessions'
					return -3
				end
		end
	if @Force = 1
		begin
			delete
			from BikeRentalDatabase.dbo.Sessions
			where RiderID = @RiderID
		end

	delete
	from BikeRentalDatabase.dbo.Riders
	where RiderID = @RiderID
	set @ErrorMessage = 'SPRemoveRider:OK'
	return 0
go

if EXISTS (select * 
		   from sysobjects
		   where [name] = 'AddSession')
   drop procedure AddSession
go

----------------------------------------------------
--Stored Procedure : 
--Inputs : int, nchar, datetime, nvarchar(OUT)
--Outputs : int
--Description: Take supplied RiderID, BikeID and date; create session
----------------------------------------------------
create procedure AddSession
@RiderID as int,
@BikeID as nchar(6),
@SessionDate datetime,
@ErrorMessage as nvarchar(MAX) out
as
	if @RiderID IS NULL
		begin
			set @ErrorMessage = 'SPAddSession:Error - RiderID can''t be NULL'
			return -1
		end
	if @BikeID IS NULL
		begin
			set @ErrorMessage = 'SPAddSession:Error - BikeID can''t be NULL'
			return -2
		end
	if @SessionDate < '2017-09-02'
		begin
			set @ErrorMessage = 'SPAddSession:Error - SessionDate [' + CONVERT(nvarchar(11), @SessionDate) + '] is too early'
			return -3
		end
	if NOT EXISTS(select * 
				  from BikeRentalDatabase.dbo.Riders
				  where RiderID = @RiderID)
		begin
			set @ErrorMessage = 'SPAddSession:Error - RiderID [' + CONVERT(nvarchar(10), @RiderID) + '] does not exists'
			return -4
		end
	if NOT EXISTS(select * 
				  from BikeRentalDatabase.dbo.Bikes
				  where BikeID = @BikeID)
		begin
			set @ErrorMessage = 'SPAddSession:Error - BikeID [' + @BikeID + '] does not exists'
			return -5
		end
	if EXISTS(select *
			  from BikeRentalDatabase.dbo.Sessions
			  where BikeID = @BikeID AND
					SessionDate = @SessionDate)
		begin
			set @ErrorMessage = 'SPAddSession:Error - Session already exists'
			return -6
		end

	insert into BikeRentalDatabase.dbo.Sessions(SessionDate, RiderID, BikeID, Laps)
	values (@SessionDate, @RiderID, @BikeID, 10)
	set @ErrorMessage = 'SPAddSession:OK'
	return 0
go

if EXISTS (select * 
		   from sysobjects
		   where [name] = 'UpdateSession')
   drop procedure UpdateSession
go

----------------------------------------------------
--Stored Procedure : Update Session
--Inputs : int, nchar, datetime, int, nvarchar(OUT)
--Outputs : int
--Description: Take supplied Session and update laps
----------------------------------------------------
create procedure UpdateSession
@RiderID as int,
@BikeID as nchar(6),
@SessionDate as datetime,
@Laps as int,
@ErrorMessage as nvarchar(MAX) out
as
	if @RiderID IS NULL
		begin
			set @ErrorMessage = 'SPUpdateSession:Error - RiderID can''t be NULL'
			return -1
		end
	if @BikeID IS NULL
		begin
			set @ErrorMessage = 'SPUpdateSession:Error - BikeID can''t be NULL'
			return -2
		end
	if @SessionDate IS NULL
		begin
			set @ErrorMessage = 'SPUpdateSession:Error - SessionDate can''t be NULL'
			return -3
		end
	if NOT EXISTS(select *
			  from BikeRentalDatabase.dbo.Sessions
			  where RiderID = @RiderID AND
					BikeID = @BikeID AND
					SessionDate = @SessionDate)
		begin
			set @ErrorMessage = 'SPUpdateSession:Error - Session doesn''t exist'
			return -4
		end
	
	if EXISTS(select *
			  from BikeRentalDatabase.dbo.Sessions
			  where RiderID = @RiderID AND
					BikeID = @BikeID AND
					SessionDate = @SessionDate AND
					@Laps < Laps)
		begin
			set @ErrorMessage = 'SPUpdateSession:Error - Input Laps is less than existing'
			return -5
		end

	update BikeRentalDatabase.dbo.Sessions
	set Laps = @Laps
	where RiderID = @RiderID AND
		  BikeID = @BikeID AND
		  SessionDate = @SessionDate

	set @ErrorMessage = 'SPUpdateSession:OK'
	return 0
go

if EXISTS (select * 
		   from sysobjects
		   where [name] = 'RemoveClass')
   drop procedure RemoveClass
go

----------------------------------------------------
--Stored Procedure : Remove Class
--Inputs : nchar, nvarchar(OUT)
--Outputs : int
--Description: Remove all relevant data that related to supplied ClassID
----------------------------------------------------
create procedure RemoveClass
@ClassID as nchar(6),
@ErrorMessage as nvarchar(MAX) out
as
	if @ClassID IS NULL
		begin
			set @ErrorMessage = 'SPRemoveClass:Error - ClassID can''t be NULL'
			return -1
		end
	if NOT EXISTS(select *
			  from BikeRentalDatabase.dbo.Class
			  where ClassID = @ClassID)
		begin
			set @ErrorMessage = 'SPRemoveClass:Error - ClassID doesn''t exists'
			return -2
		end

	delete BikeRentalDatabase.dbo.Sessions
	where RiderID IN 
	(
		select RiderID
		from BikeRentalDatabase.dbo.Riders
		where ClassID = @ClassID
	)

	delete BikeRentalDatabase.dbo.Riders
	where ClassID = @ClassID

	delete BikeRentalDatabase.dbo.Class
	where ClassID = @ClassID

	set @ErrorMessage = 'SPRemoveClass:OK'
	return 0
go

if EXISTS (select * 
		   from sysobjects
		   where [name] = 'ClassInfo')
   drop procedure ClassInfo
go

----------------------------------------------------
--Stored Procedure : Class Info
--Inputs : nchar, int, nvarchar(OUT)
--Outputs : int
--Description: Display all content that include the supplied ClassID and/or RiderID
----------------------------------------------------
create procedure ClassInfo
@ClassID as nchar(6),
@RiderID as int = NULL,
@ErrorMessage as nvarchar(MAX) out
as
	if @ClassID IS NULL
		begin
			set @ErrorMessage = 'SPClassInfo:Error - ClassID can''t be NULL'
			return -1
		end
	
	if @RiderID IS NOT NULL
		begin
			select *
			from BikeRentalDatabase.dbo.Riders
			where ClassID = @ClassID AND
				  RiderID = @RiderID

			select *
			from BikeRentalDatabase.dbo.Sessions
			where RiderID IN
			(
				select RiderID
				from BikeRentalDatabase.dbo.Riders
				where ClassID = @ClassID AND
					  RiderID = @RiderID
			)

			select *
			from BikeRentalDatabase.dbo.Bikes
			where BikeID IN
			(
				select BikeID
				from BikeRentalDatabase.dbo.Sessions
				where RiderID IN
				(
					select RiderID
					from BikeRentalDatabase.dbo.Riders
					where ClassID = @ClassID AND
						  RiderID = @RiderID
				)
			)
		end
	else
		begin
			select *
			from BikeRentalDatabase.dbo.Riders
			where ClassID = @ClassID

			select *
			from BikeRentalDatabase.dbo.Sessions
			where RiderID IN
			(
				select RiderID
				from BikeRentalDatabase.dbo.Riders
				where ClassID = @ClassID
			)

			select *
			from BikeRentalDatabase.dbo.Bikes
			where BikeID IN
			(
				select BikeID
				from BikeRentalDatabase.dbo.Sessions
				where RiderID IN
				(
					select RiderID
					from BikeRentalDatabase.dbo.Riders
					where ClassID = @ClassID
				)
			)
		end

	set @ErrorMessage = 'SPClassInfo:OK'
	return 0
go

if EXISTS (select * 
		   from sysobjects
		   where [name] = 'ClassSummary')
   drop procedure ClassSummary
go

----------------------------------------------------
--Stored Procedure : Class Summary
--Inputs : nchar, int, nvarchar(OUT)
--Outputs : int
--Description: Display session details of supplied ClassID and/or RiderID
----------------------------------------------------
create procedure ClassSummary
@ClassID as nchar(6) = NULL,
@RiderID as int = NULL,
@ErrorMessage as nvarchar(MAX) out
as
	if @ClassID IS NULL AND 
	   @RiderID IS NULL
	   begin
			select r.RiderID as 'Rider ID',
				   COALESCE(COUNT(SessionDate), 0) as 'Sessions',
				   COALESCE(MIN(Laps), 0) as 'Minimum Laps',
				   COALESCE(MAX(Laps), 0) as 'Maximum Laps',
				   COALESCE(AVG(Laps), 0) as 'Average Laps'
			from BikeRentalDatabase.dbo.Sessions as s full OUTER JOIN BikeRentalDatabase.dbo.Riders as r
				 on s.RiderID = r.RiderID
			group by r.RiderID
	   end
	else if @RiderID IS NULL
		begin
			if NOT EXISTS(select * 
						  from BikeRentalDatabase.dbo.Class
						  where ClassID = @ClassID)
				begin
					set @ErrorMessage = 'SPClassSummary:Error - ClassID [' + @ClassID + '] does not exists'
					return -1
				end	
			select r.RiderID as 'Rider ID',
				   COALESCE(COUNT(SessionDate), 0) as 'Sessions',
				   COALESCE(MIN(Laps), 0) as 'Minimum Laps',
				   COALESCE(MAX(Laps), 0) as 'Maximum Laps',
				   COALESCE(AVG(Laps), 0) as 'Average Laps'
			from BikeRentalDatabase.dbo.Sessions as s full OUTER JOIN BikeRentalDatabase.dbo.Riders as r
				 on s.RiderID = r.RiderID
			where r.ClassID = @ClassID
			group by r.RiderID 
		end
	else if @ClassID IS NULL
		begin
			
			if NOT EXISTS(select * 
						  from BikeRentalDatabase.dbo.Riders
						  where RiderID = @RiderID)
				begin
					set @ErrorMessage = 'SPClassSummary:Error - RiderID [' + CONVERT(nvarchar(10), @RiderID) + '] does not exists'
					return -2
				end
			select r.RiderID as 'Rider ID',
				   COALESCE(COUNT(SessionDate), 0) as 'Sessions',
				   COALESCE(MIN(Laps), 0) as 'Minimum Laps',
				   COALESCE(MAX(Laps), 0) as 'Maximum Laps',
				   COALESCE(AVG(Laps), 0) as 'Average Laps'
			from BikeRentalDatabase.dbo.Sessions as s full OUTER JOIN BikeRentalDatabase.dbo.Riders as r
				 on s.RiderID = r.RiderID
			where r.RiderID = @RiderID
			group by r.RiderID 
		end
	else
		begin
			
			if NOT EXISTS(select * 
						  from BikeRentalDatabase.dbo.Class
						  where ClassID = @ClassID)
				begin
					set @ErrorMessage = 'SPClassSummary:Error - ClassID [' + @ClassID + '] does not exists'
					return -1
				end
			if NOT EXISTS(select * 
						  from BikeRentalDatabase.dbo.Riders
						  where RiderID = @RiderID)
				begin
					set @ErrorMessage = 'SPClassSummary:Error - RiderID [' + CONVERT(nvarchar(10), @RiderID) + '] does not exists'
					return -2
				end

			select r.RiderID as 'Rider ID',
				   COALESCE(COUNT(SessionDate), 0) as 'Sessions',
				   COALESCE(MIN(Laps), 0) as 'Minimum Laps',
				   COALESCE(MAX(Laps), 0) as 'Maximum Laps',
				   COALESCE(AVG(Laps), 0) as 'Average Laps'
			from BikeRentalDatabase.dbo.Sessions as s full OUTER JOIN BikeRentalDatabase.dbo.Riders as r
				 on s.RiderID = r.RiderID
			where r.RiderID = @RiderID AND
				  r.ClassID = @ClassID
			group by r.RiderID 
		end

	set @ErrorMessage = 'SPClassSummary:OK'
	return 0
go

--Populate Bike Test
select *
from BikeRentalDatabase.dbo.Bikes
go

declare @error as nvarchar(MAX)
execute PopulateBikes @error out
select @error
go

select *
from BikeRentalDatabase.dbo.Bikes
go

--Populate Class Test
select *
from BikeRentalDatabase.dbo.Class
go

declare @error as nvarchar(MAX)
execute PopulateClass @error out
select @error
go

select *
from BikeRentalDatabase.dbo.Class
go

--Add Rider Test
select *
from BikeRentalDatabase.dbo.Riders
go

declare @error as nvarchar(MAX)
declare @RiderID  as int
execute @RiderID = AddRider 'Thomas Chung', 'abcdef', @error out --ClassID does not exists
select @error, @RiderID

execute @RiderID = AddRider 'Thomas Chung', 'motogp', @error out --Success
select @error, @RiderID
go

select *
from BikeRentalDatabase.dbo.Riders
go

--Add Session Test
select *
from BikeRentalDatabase.dbo.Sessions
go

declare @error as nvarchar(MAX)
execute AddSession 10, '001H-A', '2018-10-1', @error out --Success
select @error
go

select *
from BikeRentalDatabase.dbo.Sessions
go

declare @error as nvarchar(MAX)
execute AddSession 10, '001H-A', '2018-10-1', @error out --Session already exists
select @error
go

select *
from BikeRentalDatabase.dbo.Sessions
go

--Update Session Test
select *
from BikeRentalDatabase.dbo.Sessions
go

declare @error as nvarchar(MAX)
execute UpdateSession 10, '001H-A', '2018-10-1', 0, @error out -- Laps invalid
select @error
go

select *
from BikeRentalDatabase.dbo.Sessions
go

declare @error as nvarchar(MAX)
execute UpdateSession 10, '001H-A', '2018-10-1', 20, @error out -- Laps invalid
select @error
go

select *
from BikeRentalDatabase.dbo.Sessions
go


--Remove Rider Test
select *
from BikeRentalDatabase.dbo.Riders
go

select *
from BikeRentalDatabase.dbo.Sessions
go


declare @error as nvarchar(MAX)
execute RemoveRider 10, 0, @error out --Force is false, session exists for rider
select @error
go

select *
from BikeRentalDatabase.dbo.Riders
go

select *
from BikeRentalDatabase.dbo.Sessions
go


declare @error as nvarchar(MAX)
execute RemoveRider 10, 1, @error out --Force is true, success
select @error
go

select *
from BikeRentalDatabase.dbo.Riders
go

select *
from BikeRentalDatabase.dbo.Sessions
go

--Remove Class Test
--Generate Rider and Session
declare @error as nvarchar(MAX)
declare @RiderID  as int
execute @RiderID = AddRider 'Thomas Chung', 'motogp', @error out
execute AddSession @RiderID, '001H-A', '2018-10-1', @error out
go

select *
from BikeRentalDatabase.dbo.Class
go

select *
from BikeRentalDatabase.dbo.Riders
go

select *
from BikeRentalDatabase.dbo.Sessions
go

declare @error as nvarchar(MAX)
execute RemoveClass 'motogp', @error out --Force is true, success
select @error
go

select *
from BikeRentalDatabase.dbo.Class
go

select *
from BikeRentalDatabase.dbo.Riders
go

select *
from BikeRentalDatabase.dbo.Sessions
go


--Class Info Test
--Generate Rider and Session
declare @error as nvarchar(MAX)
declare @RiderID  as int
execute @RiderID = AddRider 'Thomas Chung', 'moto_3', @error out
execute AddSession @RiderID, '001H-A', '2018-10-1', @error out
go

declare @error as nvarchar(MAX)
execute ClassInfo 'moto_3', NULL, @error out
select @error
go

--ClassSummary
--Generate Rider
declare @error as nvarchar(MAX)
declare @RiderID  as int
execute @RiderID = AddRider 'Monkey', 'moto_3', @error out
go

declare @error as nvarchar(MAX)
execute ClassSummary NULL, NULL, @error out
select @error
go