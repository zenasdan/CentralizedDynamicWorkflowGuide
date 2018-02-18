ALTER PROCEDURE [dbo].[WorkflowGuide_SelectWorkflowItemsByUserBaseId] 
@UserBaseId int
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

/*
	--TEST CODE
	DECLARE	@return_value int

	EXEC	@return_value = [dbo].[WorkflowGuide_SelectWorkflowItemsByUserBaseIdd]
			@UserBaseId = XX

	SELECT	'Return Value' = @return_value

*/
	DECLARE @UserProfileId int;
	DECLARE @RoleName nvarchar(50);
	DECLARE @TimeApprovedStatusTypeId int = 1;
	SELECT @UserProfileId = Id FROM UserProfile WHERE UserBaseId = @UserBaseId;

	--CHECK IF USER IS A BROKER OR CLIENT
	IF (SELECT COUNT(*) FROM UserBaseAppRole UBAR INNER JOIN AppRole AR ON AR.Id = UBAR.AppRoleId WHERE UserBaseId = @UserBaseId AND AR.RoleName = 'Broker') > 0 
	BEGIN
		SET @RoleName = 'Broker'
	END
	ELSE 
	BEGIN 
		SET @RoleName = 'Client'
	END	
	
	--IF USER IS A BROKER, THEY WILL RECEIVE THE BELOW MESSAGES FOR THE CORRESPONDING STEPS IN THE WORK FLOW
	IF (@RoleName = 'Broker')
	BEGIN
		--SET CREATE TEAM MESSAGE FOR TEAMS WHERE I AM THE ONLY MEMBER ON THAT TEAM
		SELECT CONCAT('Invite team members for team', ' ', T1.Title) AS MessageText, 'AddTeam' AS NotificationType, '/Member/TeamManagement' AS ActionItem
		FROM Team T1 LEFT JOIN TeamMember TM1 ON TM1.TeamId = T1.Id WHERE TM1.UserProfileId = @UserProfileId
		AND (SELECT COUNT(*) FROM Team T LEFT JOIN TeamMember TM ON TM.TeamId = T.Id WHERE T.Id = TM1.TeamId) <= 1
		UNION
		--CREATE PROJECT/TENANT REQUIREMENTS
		SELECT CONCAT('Create project and submit tenant requirements for team: ', T.Title), 'AddProjectRequirements', CAST(T.Id AS varchar)
		FROM TenantRequestQueue TRQ
		RIGHT JOIN TeamMember TM ON TM.TeamId = TRQ.TeamId
		JOIN Team T ON T.Id = TM.TeamId
		WHERE TM.UserProfileId = @UserProfileId AND TRQ.TenantRequirementId IS NULL
		UNION
		--ADD SOME NOTES FOR THE PROJECT
		SELECT CONCAT('Add a Note for Project: ', P.ProjectName), 'AddProjectNotes', CAST(P.Id AS varchar) 
		FROM Note N  
		RIGHT JOIN Project P ON P.Id = N.ProjectId
		JOIN TeamProject TP ON TP.ProjectId = P.Id 
		JOIN TeamMember TM ON TM.TeamId = TP.TeamId
		WHERE TM.UserProfileId = @UserProfileId AND N.ProjectId IS NULL
		UNION
		--CREATE A TIMELINE
		SELECT CONCAT('Create a timeline for project: ', P.ProjectName), 'AddTimeline', CAST(P.Id AS varchar)  
		FROM ProjectTimeLineRel PTLR
		RIGHT JOIN Project P ON P.Id = PTLR.ProjectId
		JOIN TeamProject TP ON TP.ProjectId = P.Id 
		JOIN TeamMember TM ON TM.TeamId = TP.TeamId
		WHERE TM.UserProfileId = @UserProfileId AND PTLR.TemplateId IS NULL
		UNION
		--ADD A PROPERTY 
		SELECT CONCAT('Add a property for project: ', P.ProjectName), 'AddProperty', CAST(P.Id AS varchar)
		FROM ProjectProperty PP 
		RIGHT JOIN Project P ON P.Id = PP.ProjectId
		JOIN TeamProject TP ON TP.ProjectId = P.Id 
		JOIN TeamMember TM ON TM.TeamId = TP.TeamId 
		WHERE TM.UserProfileId = @UserProfileId AND PP.PropertyId IS NULL
		UNION
		--APPROVE TOUR DATE TIME
		SELECT CONCAT('Approve the requested tour date For: ', A.StreetAddress, ', ', A.City, ', ', SP.StateProvinceCode, A.PostalCode, 
		' of Project: ', P.ProjectName), 'ApproveTourDate', CONCAT('/Member/PropertyStatusManager/', P.Id) 
		FROM PropertyTourDate PTD
		JOIN ProjectProperty PP ON PTD.PropertyId = PP.PropertyId AND PTD.ProjectId = PP.ProjectId
		JOIN Property PROP ON PP.PropertyId = PROP.Id
		JOIN Address A ON A.Id = PROP.AddressId
		JOIN StateProvince SP ON A.StateId = SP.Id
		JOIN Project P ON P.Id = PP.ProjectId
		JOIN TeamProject TP ON TP.ProjectId = P.Id 
		JOIN TeamMember TM ON TM.TeamId = TP.TeamId 
		WHERE TM.UserProfileId = @UserProfileId AND PTD.ClientConfirmed IS NULL AND PTD.TourStatusTypeId <> @TimeApprovedStatusTypeId
		UNION
		--ADD SOME NOTES FOR THE PROPERTY
		SELECT CONCAT('Add a note for property: ', A.StreetAddress, ', ', A.City, ', ', SP.StateProvinceCode, A.PostalCode), 'AddPropertyNotes', CONCAT('/Member/PropertyTourNotes/', P.Id) 
		FROM Note N
		RIGHT JOIN Property PROP ON PROP.Id = N.EntityId
		JOIN ProjectProperty PP ON PROP.Id = PP.PropertyId
		JOIN PropertyTourDate PTD ON PTD.PropertyId = PP.PropertyId
		JOIN Project P ON P.Id = PTD.ProjectId
		JOIN Address A ON PROP.AddressId = A.Id
		JOIN StateProvince SP ON A.StateId = SP.Id
		JOIN TeamProject TP ON TP.ProjectId = PP.ProjectId 
		JOIN TeamMember TM ON TM.TeamId = TP.TeamId 
		WHERE TM.UserProfileId = @UserProfileId AND N.EntityId IS NULL 
		AND PTD.TourDate IS NOT NULL AND PTD.ClientConfirmed IS NOT NULL
		AND PP.ProjectId = PTD.ProjectId
		--CREATE PROPOSALS
		UNION
		SELECT CONCAT('Create a lease proposal for property: ', A.StreetAddress, ', ', A.City, ', ', SP.StateProvinceCode, A.PostalCode,' of Project: ', P.ProjectName), 'CreateLeaseProposal', CONCAT('/Member/LeaseProposal/', P.Id) 
		FROM Property PR
		INNER JOIN ProjectProperty PP ON PP.PropertyId = PR.Id
		INNER JOIN Project P ON P.Id = PP.ProjectId
		INNER JOIN Address A ON A.Id = PR.AddressId
		INNER JOIN StateProvince SP ON SP.Id = A.StateId
		INNER JOIN TeamProject TP ON P.Id = TP.ProjectId
		INNER JOIN TeamMember TM ON TM.TeamId = TP.TeamId
		INNER JOIN PropertyProposal PPROP ON PPROP.ProjectId = P.Id AND PPROP.PropertyId = PR.Id AND PPROP.IsApproved IS NULL AND PPROP.LeaseProposalId IS NULL
		--ALL REQUESTED PROPERTIES THAT HAVE NO FILE
		WHERE TM.UserProfileId = @UserProfileId 
		--UPDATE REJECTED PROPOSALS
		UNION
		SELECT CONCAT('Review notes for rejected lease proposal on property: ', A.StreetAddress, ', ', A.City, ', ', SP.StateProvinceCode, A.PostalCode,' of Project: ', P.ProjectName), 'CreateLeaseProposal', CONCAT('/Member/LeaseProposal/', P.Id) 
		From Property PR
		INNER JOIN ProjectProperty PP ON PP.PropertyId = PR.Id
		INNER JOIN Project P ON P.Id = PP.ProjectId
		INNER JOIN Address A ON A.Id = PR.AddressId
		INNER JOIN StateProvince SP ON SP.Id = A.StateId
		INNER JOIN TeamProject TP ON P.Id = TP.ProjectId
		INNER JOIN TeamMember TM ON TM.TeamId = TP.TeamId
		INNER JOIN PropertyProposal PPROP ON PPROP.ProjectId = P.Id AND PPROP.PropertyId = PR.Id AND PPROP.IsApproved = 0	
		--ALL REQUESTED PROPERTIES THAT HAVE REJECTION
		WHERE TM.UserProfileId = @UserProfileId
		--UPLOAD COUNTER PROPOSALS
		UNION
		SELECT CONCAT('Upload landlord counter on property: ', A.StreetAddress, ', ', A.City, ', ', SP.StateProvinceCode, A.PostalCode,' of Project: ', P.ProjectName), 'LandlordCounter', CONCAT('/Member/LandlordCounters/', P.Id) 
		From Property PR
		INNER JOIN ProjectProperty PP ON PP.PropertyId = PR.Id
		INNER JOIN Project P ON P.Id = PP.ProjectId
		INNER JOIN Address A ON A.Id = PR.AddressId
		INNER JOIN StateProvince SP ON SP.Id = A.StateId
		INNER JOIN TeamProject TP ON P.Id = TP.ProjectId
		INNER JOIN TeamMember TM ON TM.TeamId = TP.TeamId
		INNER JOIN PropertyProposal PPROP ON PPROP.ProjectId = P.Id AND PPROP.PropertyId = PR.Id AND PPROP.IsApproved = 1
		--PROJECT HAS ACCEPTED PROPERTY PROPOSAL BUT NO FILES UPLOADED FOR COUNTERS YET
		WHERE TM.UserProfileId = @UserProfileId AND (SELECT COUNT(fileId) FROM LandlordCounters LC WHERE LC.ProjectId = P.Id) = 0
		--UPDATE COUNTER PROPOSALS
		UNION
		SELECT CONCAT('Update and review notes for rejected landlord counter on property: ', A.StreetAddress, ', ', A.City, ', ', SP.StateProvinceCode, A.PostalCode,' of Project: ', P.ProjectName), 'LandlordCounter', CONCAT('/Member/LandlordCounters/', P.Id) 
		From Property PR
		INNER JOIN ProjectProperty PP ON PP.PropertyId = PR.Id
		INNER JOIN Project P ON P.Id = PP.ProjectId
		INNER JOIN Address A ON A.Id = PR.AddressId
		INNER JOIN StateProvince SP ON SP.Id = A.StateId
		INNER JOIN TeamProject TP ON P.Id = TP.ProjectId
		INNER JOIN TeamMember TM ON TM.TeamId = TP.TeamId
		INNER JOIN PropertyProposal PPROP ON PPROP.ProjectId = P.Id AND PPROP.PropertyId = PR.Id AND PPROP.IsApproved = 1
		INNER JOIN LandlordCounters LC ON LC.ProjectId = P.Id AND LC.PropertyId = PR.Id AND LC.Approved = 0 --REJECTED
		WHERE TM.UserProfileId = @UserProfileId
		--UPLOAD LEASE DRAFT
		UNION
		SELECT CONCAT('Upload Lease Draft for property: ', A.StreetAddress, ', ', A.City, ', ', SP.StateProvinceCode, A.PostalCode,' of Project: ', P.ProjectName), 'LeaseDraft', CONCAT('/Member/BrokerLeaseDraft/', P.Id) 
		From Property PR
		INNER JOIN ProjectProperty PP ON PP.PropertyId = PR.Id
		INNER JOIN Project P ON P.Id = PP.ProjectId
		INNER JOIN Address A ON A.Id = PR.AddressId
		INNER JOIN StateProvince SP ON SP.Id = A.StateId
		INNER JOIN TeamProject TP ON P.Id = TP.ProjectId
		INNER JOIN TeamMember TM ON TM.TeamId = TP.TeamId
		INNER JOIN PropertyProposal PPROP ON PPROP.ProjectId = P.Id AND PPROP.PropertyId = PR.Id AND PPROP.IsApproved = 1
		INNER JOIN LandlordCounters LC ON LC.ProjectId = P.Id AND LC.PropertyId = PR.Id AND LC.Approved = 1
 		WHERE TM.UserProfileId = @UserProfileId AND (SELECT COUNT(fileid) FROM BrokerLeaseDraft BLD WHERE BLD.ProjectId = P.Id) = 0
		--UPDATE REJECTED LEASE DRAFT
		UNION
		SELECT CONCAT('Update Rejected Lease Draft for property: ', A.StreetAddress, ', ', A.City, ', ', SP.StateProvinceCode, A.PostalCode,' of Project: ', P.ProjectName), 'LeaseDraft', CONCAT('/Member/BrokerLeaseDraft/', P.Id) 
		From Property PR
		INNER JOIN ProjectProperty PP ON PP.PropertyId = PR.Id
		INNER JOIN Project P ON P.Id = PP.ProjectId
		INNER JOIN Address A ON A.Id = PR.AddressId
		INNER JOIN StateProvince SP ON SP.Id = A.StateId
		INNER JOIN TeamProject TP ON P.Id = TP.ProjectId
		INNER JOIN TeamMember TM ON TN.TeamId = TP.TeamId
		INNER JOIN PropertyProposal PPROP ON PPROP.ProjectId = P.Id AND PPROP.PropertyId = PR.Id AND PPROP.IsApproved = 1
		INNER JOIN LandlordCounters LC ON LC.ProjectId = P.Id AND LC.PropertyId = PR.Id AND LC.Approved = 1
		INNER JOIN BrokerLeaseDraft BLD ON BLD.ProjectId = P.Id AND BLD.PropertyId = PR.Id AND BLD.Approved = 0 --REJECTED
		WHERE TM.UserProfileId = @UserProfileId 
		--DOWNLOAD SIGNED LEASE
		UNION
		SELECT CONCAT('Download tenant final paperwork for property: ', A.StreetAddress, ', ', A.City, ', ', SP.StateProvinceCode, A.PostalCode,' of Project: ', P.ProjectName), 'SignLease', CONCAT('/Member/tenantFinalPaperwork/', P.Id) 
		From Property PR
		INNER JOIN ProjectProperty PP ON PP.PropertyId = PR.Id
		INNER JOIN Project P ON P.Id = PP.ProjectId
		INNER JOIN Address A ON A.Id = PR.AddressId
		INNER JOIN StateProvince SP ON SP.Id = A.StateId
		INNER JOIN TeamProject TP ON P.Id = TP.ProjectId
		INNER JOIN TeamMember TM ON TM.TeamId = TP.TeamId
		INNER JOIN PropertyProposal PPROP ON PPROP.ProjectId = P.Id AND PPROP.PropertyId = PR.Id AND PPROP.IsApproved = 1
		INNER JOIN LandlordCounters LC ON LC.ProjectId = P.Id AND LC.PropertyId = PR.Id AND LC.Approved = 1
		INNER JOIN BrokerLeaseDraft BLD ON BLD.ProjectId = P.Id AND BLD.PropertyId = PR.Id AND BLD.Approved = 1
		INNER JOIN LeaseSignedFile LSF ON LSF.ProjectId = P.Id AND LSF.PropertyId = PR.Id 
		WHERE TM.UserProfileId = @UserProfileId 
	END
	--IF USER IS A CLIENT, THEY WILL RECEIVE THE BELOW MESSAGES FOR THE CORRESPONDING STEPS IN THE WORK FLOW
	ELSE IF (@RoleName = 'Client')
	BEGIN
		--SET CREATE TEAM MESSAGE FOR TEAMS WHERE I AM THE ONLY MEMBER ON THAT TEAM
		SELECT CONCAT('Invite team members for team', ' ', T1.Title) AS MessageText, 'AddTeam' AS NotificationType, '/Member/TeamManagement' AS ActionItem 
		FROM Team T1 LEFT JOIN TeamMember TM1 ON TM1.TeamId = T1.Id WHERE TM1.UserProfileId = @UserProfileId
		AND (SELECT COUNT(*) FROM Team T LEFT JOIN TeamMember TM ON TM.TeamId = T.Id WHERE T.Id = TM1.TeamId) <= 1
		UNION
		--CREATE PROJECT/TENANT REQUIREMENTS
		SELECT CONCAT('Create project and submit tenant requirements for team: ', T.Title), 'AddProjectRequirements', CAST(T.Id AS varchar) 
		FROM TenantRequestQueue TRQ
		RIGHT JOIN TeamMember TM ON TM.TeamId = TRQ.TeamId
		JOIN Team T ON T.Id = TM.TeamId
		WHERE TM.UserProfileId = @UserProfileId AND TRQ.TenantRequirementId IS NULL
		UNION
		--ADD SOME NOTES FOR THE PROJECT
		SELECT CONCAT('Add a Note for Project: ', P.ProjectName), 'AddProjectNotes', CAST(P.Id AS varchar)  
		FROM Note N
		RIGHT JOIN Project P ON P.Id = N.ProjectId
		JOIN TeamProject TP ON TP.ProjectId = P.Id 
		JOIN TeamMember TM ON TM.TeamId = TP.TeamId
		WHERE TM.UserProfileId = @UserProfileId AND N.ProjectId IS NULL
		UNION
		--CREATE A TIMELINE
		SELECT CONCAT('Create a timeline for project: ', P.ProjectName), 'AddTimeline', CAST(P.Id AS varchar)
		FROM ProjectTimeLineRel PTLR
		RIGHT JOIN Project P ON P.Id = PTLR.ProjectId
		JOIN TeamProject TP ON TP.ProjectId = P.Id 
		JOIN TeamMember TM ON TM.TeamId = TP.TeamId
		WHERE TM.UserProfileId = @UserProfileId AND PTLR.TemplateId IS NULL
		UNION
		--ADD A PROPERTY 
		SELECT CONCAT('Add a property for project: ', P.ProjectName), 'AddProperty', CAST(P.Id AS varchar)
		FROM ProjectProperty PP
		RIGHT JOIN Project P ON P.Id = PP.ProjectId
		JOIN TeamProject TP ON TP.ProjectId = P.Id 
		JOIN TeamMember TM ON TM.TeamId = TP.TeamId 
		WHERE TM.UserProfileId = @UserProfileId AND PP.PropertyId IS NULL
		UNION
		--CHOOSE A TOUR DATE FOR PROJECT
		SELECT CONCAT('Choose a tour date for project: ', P.ProjectName), 'RequestTourDate', CONCAT('/Member/ChooseProperty/', P.Id)
		FROM PropertyTourDate PTD
		RIGHT JOIN ProjectProperty PP ON PTD.PropertyId = PP.PropertyId AND PTD.ProjectId = PP.ProjectId
		JOIN Property PROP ON PP.PropertyId = PROP.Id
		JOIN Address A ON A.Id = PROP.AddressId
		JOIN StateProvince SP ON A.StateId = SP.Id
		JOIN Project P ON P.Id = PP.ProjectId
		JOIN TeamProject TP ON TP.ProjectId = P.Id 
		JOIN TeamMember TM ON TM.TeamId = TP.TeamId 
		WHERE TM.UserProfileId = @UserProfileId AND PTD.TourDate IS NULL
		UNION
		--CONFIRM TOUR DATE AFTER BROKER APPROVAL
		SELECT CONCAT('There is a tour date awaiting your confirmation. Please confirm tour date for project: ', P.ProjectName), 'ConfirmTourDate', CONCAT('/Member/PropertyStatusManager/', P.Id) 
		FROM PropertyTourDate PTD
		JOIN ProjectProperty PP ON PP.PropertyId = PTD.PropertyId AND PTD.ProjectId = PP.ProjectId
		JOIN Property PROP ON PP.PropertyId = PROP.Id
		JOIN Address A ON PROP.AddressId = A.Id
		JOIN StateProvince SP ON A.StateId = SP.Id
		JOIN Project P ON P.Id = PP.ProjectId
		JOIN TeamProject TP ON TP.ProjectId = P.Id 
		JOIN TeamMember TM ON TP.TeamId = TM.TeamId
		WHERE TM.UserProfileId = @UserProfileId AND PTD.ClientConfirmed IS NULL AND PTD.TourStatusTypeId = @TimeApprovedStatusTypeId
		UNION
		--ADD SOME NOTES FOR THE PROPERTY
		SELECT CONCAT('Add a note for property: ', A.StreetAddress, ', ', A.City, ', ', SP.StateProvinceCode, A.PostalCode), 'AddPropertyNotes', CONCAT('/Member/PropertyTourNotes/', P.Id) 
		FROM Note N
		RIGHT JOIN Property PROP ON PROP.Id = N.EntityId
		JOIN ProjectProperty PP ON PROP.Id = PP.PropertyId
		JOIN PropertyTourDate PTD ON PTD.PropertyId = PP.PropertyId
		JOIN Project P ON P.Id = PTD.ProjectId
		JOIN Address A ON PROP.AddressId = A.Id
		JOIN StateProvince SP ON A.StateId = SP.Id
		JOIN TeamProject TP ON TP.ProjectId = PP.ProjectId 
		JOIN TeamMember TM ON TM.TeamId = TP.TeamId 
		WHERE TM.UserProfileId = @UserProfileId AND N.EntityId IS NULL 
		AND PTD.TourDate IS NOT NULL AND PTD.ClientConfirmed IS NOT NULL
		AND PP.ProjectId = PTD.ProjectId
		--REQUEST PROPOSALS
		UNION
		SELECT CONCAT('Request proposal for project: ', P.ProjectName), 'RequestProposal', CONCAT('/Member/PropertyProposal/', P.Id) 
		From Property PR
		INNER JOIN ProjectProperty PP ON PP.PropertyId = PR.Id
		INNER JOIN Project P ON P.Id = PP.ProjectId
		INNER JOIN Address A ON A.Id = PR.AddressId
		INNER JOIN StateProvince SP ON SP.Id = A.StateId
		INNER JOIN TeamProject TP ON P.Id = TP.ProjectId
		INNER JOIN TeamMember TM ON TM.TeamId = TP.TeamId
		INNER JOIN PropertyTourDate PTD ON PTD.ProjectId = P.Id AND PTD.PropertyId = PR.Id AND PTD.ClientConfirmed = 1
		LEFT JOIN PropertyProposal PPROP ON PPROP.ProjectId = P.Id AND PPROP.PropertyId = PR.Id AND PPROP.IsApproved IS NULL AND PPROP.LeaseProposalId IS NULL
		WHERE TM.UserProfileId = @UserProfileId AND PTD.TourDate <= GETUTCDATE() AND (SELECT COUNT(PPR.SelectedDate)
		from PropertyProposal PPR WHERE PPR.ProjectId = P.Id) = 0
		--APPROVE/REJECT PROPOSALS
		UNION
		SELECT CONCAT('Review proposal for project: ', P.ProjectName), 'RequestProposal', CONCAT('/Member/PropertyProposal/', P.Id) 
		From Property PR
		INNER JOIN ProjectProperty PP ON PP.PropertyId = PR.Id
		INNER JOIN Project P ON P.Id = PP.ProjectId
		INNER JOIN Address A ON A.Id = PR.AddressId
		INNER JOIN StateProvince SP ON SP.Id = A.StateId
		INNER JOIN TeamProject TP ON P.Id = TP.ProjectId
		INNER JOIN TeamMember TM ON TM.TeamId = TP.TeamId
		INNER JOIN PropertyTourDate PTD ON PTD.ProjectId = P.Id AND PTD.PropertyId = PR.Id AND PTD.ClientConfirmed = 1
		INNER JOIN PropertyProposal PPROP ON PPROP.ProjectId = P.Id AND PPROP.PropertyId = PR.Id AND PPROP.IsApproved IS NULL AND PPROP.LeaseProposalId IS NOT NULL
		WHERE TM.UserProfileId = @UserProfileId AND (SELECT COUNT(PPR.IsApproved)
		from PropertyProposal PPR WHERE PPR.ProjectId = P.Id AND PPR.IsApproved = 1) = 0 
		--REVIEW LANDLORD COUNTER
		UNION
		SELECT CONCAT('Review landlord counter for project: ', P.ProjectName), 'LandlordCounter', CONCAT('/Member/LandlordCounters/', P.Id) 
		From Property PR
		INNER JOIN ProjectProperty PP ON PP.PropertyId = PR.Id
		INNER JOIN Project P ON P.Id = PP.ProjectId
		INNER JOIN Address A ON A.Id = PR.AddressId
		INNER JOIN StateProvince SP ON SP.Id = A.StateId
		INNER JOIN TeamProject TP ON P.Id = TP.ProjectId
		INNER JOIN TeamMember TM ON TM.TeamId = TP.TeamId
		INNER JOIN PropertyTourDate PTD ON PTD.ProjectId = P.Id AND PTD.PropertyId = PR.Id AND PTD.ClientConfirmed = 1
		INNER JOIN PropertyProposal PPROP ON PPROP.ProjectId = P.Id AND PPROP.PropertyId = PR.Id AND PPROP.IsApproved = 1
		INNER JOIN LandlordCounters LC ON LC.ProjectId = P.Id AND LC.PropertyId = PR.Id AND LC.fileId IS NOT NULL AND LC.Approved IS NULL
		WHERE TM.UserProfileId = @UserProfileId AND (SELECT COUNT(LC.Approved)
		from LandlordCounters LC WHERE LC.ProjectId = P.Id and LC.Approved = 1) = 0 
		--REVIEW BROKER LEASE DRAFT
		UNION
		SELECT CONCAT('Review lease draft for project: ', P.ProjectName), 'LeaseDraft', CONCAT('/Member/brokerleasedraft/', P.Id) 
		From Property PR
		INNER JOIN ProjectProperty PP ON PP.PropertyId = PR.Id
		INNER JOIN Project P ON P.Id = PP.ProjectId
		INNER JOIN Address A ON A.Id = PR.AddressId
		INNER JOIN StateProvince SP ON SP.Id = A.StateId
		INNER JOIN TeamProject TP ON P.Id = TP.ProjectId
		INNER JOIN TeamMember TM ON TM.TeamId = TP.TeamId
		INNER JOIN PropertyTourDate PTD ON PTD.ProjectId = P.Id AND PTD.PropertyId = PR.Id AND PTD.ClientConfirmed = 1
		INNER JOIN PropertyProposal PPROP ON PPROP.ProjectId = P.Id AND PPROP.PropertyId = PR.Id AND PPROP.IsApproved = 1
		INNER JOIN LandlordCounters LC ON LC.ProjectId = P.Id AND LC.PropertyId = PR.Id AND LC.Approved = 1
		INNER JOIN BrokerLeaseDraft BLD ON BLD.ProjectId = P.Id AND BLD.PropertyId = PR.Id
		--GET PROJECT WHERE PROP HAS APPROVED COUNTER BUT NO APPROVED LEASE DRAFT
		WHERE TM.UserProfileId = @UserProfileId AND (SELECT COUNT(BLD.Approved) FROM BrokerLeaseDraft BLD WHERE BLD.ProjectId = P.Id AND BLD.Approved = 1) = 0 
		--UPLOAD TENANT FINAL PAPERWORK
		UNION
		SELECT CONCAT('Sign lease for property: ', A.StreetAddress, ', ', A.City, ', ', SP.StateProvinceCode, A.PostalCode, ' for project: ', P.Id ), 'SignLease', CONCAT('/Member/tenantfinalpaperwork/', P.Id) 
		From Property PR
		INNER JOIN ProjectProperty PP ON PP.PropertyId = PR.Id
		INNER JOIN Project P ON P.Id = PP.ProjectId
		INNER JOIN Address A ON A.Id = PR.AddressId
		INNER JOIN StateProvince SP ON SP.Id = A.StateId
		INNER JOIN TeamProject TP ON P.Id = TP.ProjectId
		INNER JOIN TeamMember TM ON TM.TeamId = TP.TeamId
		INNER JOIN PropertyTourDate PTD ON PTD.ProjectId = P.Id AND PTD.PropertyId = PR.Id AND PTD.ClientConfirmed = 1
		INNER JOIN PropertyProposal PPROP ON PPROP.ProjectId = P.Id AND PPROP.PropertyId = PR.Id AND PPROP.IsApproved = 1
		INNER JOIN LandlordCounters LC ON LC.ProjectId = P.Id AND LC.PropertyId = PR.Id AND LC.Approved = 1
		INNER JOIN BrokerLeaseDraft BLD ON BLD.ProjectId = P.Id AND BLD.PropertyId = PR.Id AND BLD.Approved = 1 
		--GET PROJECT WHERE PROP HAS APPROVED BROKER LEASE DRAFT BUT NO UPLOADED FINAL FILE
		WHERE TM.UserProfileId = @UserProfileId AND (SELECT COUNT(LSF.FileRepositoryId) FROM LeaseSignedFile LSF WHERE LSF.ProjectId = P.Id AND LSF.FileRepositoryId IS NOT NULL) = 0 
	END

END