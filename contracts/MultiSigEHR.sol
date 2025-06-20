// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MultiSigEHR {
    uint public minApprovalsRequired = 2;

    struct Doctor {
        string name;
        address wallet;
        bool isRegistered;
    }

    struct Patient {
        string name;
        address wallet;
        bool isRegistered;
    }

    struct MedicalRecord {
        string ipfsHash;
        address uploadedBy;
    }

    mapping(address => Doctor) public doctors;
    mapping(address => Patient) public patients;
    mapping(address => MedicalRecord[]) public patientRecords;

    mapping(address => address[]) public trustedDoctors; // for display
    mapping(address => mapping(address => bool)) public isTrustedDoctor; // fast lookup

    struct ViewRequest {
        address patient;
        address requester;
        uint approvalCount;
        mapping(address => bool) approvals;
        bool granted;
    }

    mapping(bytes32 => ViewRequest) private viewRequests;

    event DoctorRegistered(address doctor, string name);
    event PatientRegistered(address patient, string name);
    event RecordUploaded(address patient, string ipfsHash);
    event ViewRequested(address patient, address doctor);
    event ViewApproved(address patient, address doctor, address approver);
    event AccessGranted(address patient, address doctor);
    event TrustedDoctorAdded(address patient, address doctor);
    event TrustedDoctorRemoved(address patient, address doctor);

    modifier onlyDoctor() {
        require(doctors[msg.sender].isRegistered, "Only doctor");
        _;
    }

    modifier onlyPatient() {
        require(patients[msg.sender].isRegistered, "Only patient");
        _;
    }

    function registerDoctor(string memory _name) external {
        require(!doctors[msg.sender].isRegistered, "Doctor already registered");
        doctors[msg.sender] = Doctor(_name, msg.sender, true);
        emit DoctorRegistered(msg.sender, _name);
    }

    function registerPatient(string memory _name) external {
        require(!patients[msg.sender].isRegistered, "Patient already registered");
        patients[msg.sender] = Patient(_name, msg.sender, true);
        emit PatientRegistered(msg.sender, _name);
    }

    function uploadRecord(string memory _ipfsHash) external onlyPatient {
        patientRecords[msg.sender].push(MedicalRecord(_ipfsHash, msg.sender));
        emit RecordUploaded(msg.sender, _ipfsHash);
    }

    function addTrustedDoctor(address _doctor) external onlyPatient {
        require(doctors[_doctor].isRegistered, "Not a registered doctor");
        require(!isTrustedDoctor[msg.sender][_doctor], "Doctor already trusted");

        trustedDoctors[msg.sender].push(_doctor);
        isTrustedDoctor[msg.sender][_doctor] = true;

        emit TrustedDoctorAdded(msg.sender, _doctor);
    }

    function removeTrustedDoctor(address _doctor) external onlyPatient {
        require(isTrustedDoctor[msg.sender][_doctor], "Doctor not trusted");

        address[] storage list = trustedDoctors[msg.sender];
        for (uint i = 0; i < list.length; i++) {
            if (list[i] == _doctor) {
                list[i] = list[list.length - 1];
                list.pop();
                break;
            }
        }
        isTrustedDoctor[msg.sender][_doctor] = false;
        emit TrustedDoctorRemoved(msg.sender, _doctor);
    }

    function requestRecordView(address _patient) external onlyDoctor {
        require(patients[_patient].isRegistered, "Patient not registered");

        bytes32 requestId = keccak256(abi.encodePacked(_patient, msg.sender));
        ViewRequest storage req = viewRequests[requestId];

        require(!req.granted, "Access already granted");
        require(req.requester == address(0), "Request already exists");

        req.patient = _patient;
        req.requester = msg.sender;

        emit ViewRequested(_patient, msg.sender);
    }

    function approveRecordView(address _patient, address _requester) external onlyDoctor {
        bytes32 requestId = keccak256(abi.encodePacked(_patient, _requester));
        ViewRequest storage req = viewRequests[requestId];

        require(!req.granted, "Already granted");
        require(!req.approvals[msg.sender], "Already approved");
        require(isTrustedDoctor[_patient][msg.sender], "Doctor not trusted");

        req.approvals[msg.sender] = true;
        req.approvalCount++;

        emit ViewApproved(_patient, _requester, msg.sender);

        if (req.approvalCount >= minApprovalsRequired) {
            req.granted = true;
            emit AccessGranted(_patient, _requester);
        }
    }

    function canViewRecords(address _patient, address _requester) public view returns (bool) {
        bytes32 requestId = keccak256(abi.encodePacked(_patient, _requester));
        return viewRequests[requestId].granted;
    }

    function getPatientRecords(address _patient) external view onlyDoctor returns (MedicalRecord[] memory) {
        require(canViewRecords(_patient, msg.sender), "Access not granted");
        return patientRecords[_patient];
    }

    function getTrustedDoctors(address _patient) external view returns (address[] memory) {
        return trustedDoctors[_patient];
    }

    function getApprovalsCount(address _patient, address _requester) external view returns (uint) {
        bytes32 requestId = keccak256(abi.encodePacked(_patient, _requester));
        return viewRequests[requestId].approvalCount;
    }

    function hasApproved(address _patient, address _requester, address _approver) external view returns (bool) {
        bytes32 requestId = keccak256(abi.encodePacked(_patient, _requester));
        return viewRequests[requestId].approvals[_approver];
    }
}
