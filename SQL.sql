
CREATE TABLE `charge` (
  `LoanTax` double NOT NULL DEFAULT '0',
  `LoanDirectExpenses` double NOT NULL DEFAULT '0',
  `LoanInsurance` double NOT NULL DEFAULT '0',
  `LoanQualityAssurance` double NOT NULL DEFAULT '0',
  `StatementDirectCost` double NOT NULL DEFAULT '0',
  `StatementIndirectCost` double NOT NULL DEFAULT '0',
  `DirectCost` double NOT NULL DEFAULT '0',
  `InterestExpenses` double NOT NULL DEFAULT '0',
  `GovernmentRevenue` double NOT NULL DEFAULT '0',
  `LoanInterest` double NOT NULL DEFAULT '0',
  `Depreciation` double NOT NULL DEFAULT '0',
  `ID` int(11) PRIMARY  KEY AUTO_INCREMENT
) ENGINE=InnoDB DEFAULT CHARSET=latin1;



CREATE TABLE `customer` (
  `FirstName` varchar(50) NOT NULL,
  `LastName` varchar(50) NOT NULL,
  `FullName` varchar(50) AS (CONCAT(firstname,' ',lastname)) PERSISTENT,
  `CustomerNationaID` varchar(50) PRIMARY  KEY ,
  `Resident` varchar(50) NOT NULL,
  `password` varchar (50),
  `AddedBy` varchar(50) NOT NULL,
  FOREIGN KEY (AddedBy)references  employee(EmployeeID) ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;



CREATE TABLE `department` (
  `DepartmentName` varchar(50) PRIMARY KEY ,
  `HeadOfDepartment` varchar(50) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;


CREATE TABLE `employee` (
  `FirstName` varchar(50) NOT NULL,
  `LastName` varchar(50) NOT NULL,
  `FullName` varchar(50) AS (CONCAT(firstname,' ',lastname)) PERSISTENT,
  `DepartmentName` varchar(50) NOT NULL,
  `EmployeeID` varchar(50) PRIMARY KEY,
  FOREIGN KEY (DepartmentName)references  department(DepartmentName) ON UPDATE CASCADE ON DELETE SET NULL,
) ENGINE=InnoDB DEFAULT CHARSET=latin1;



CREATE TABLE `installments` (
  `LoanId_FK` varchar(50) NOT NULL,
  `InstallmentID` int(11) PRIMARY KEY AUTO_INCREMENT,
  `InstallmentNumber` int(11) NOT NULL,
  `CustomerNationalID_FK` varchar(50) NOT NULL,
  `InstalledAmount` double NOT NULL,
  `EmployeeID_FK` varchar(50) NOT NULL,
  `InstallmentDate` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY(LoanId_FK)references loan(LoanID) on update CASCADE,
  FOREIGN KEY(CustomerNationalID_FK)references customer(CustomerNationaID) on update CASCADE,
  FOREIGN KEY(EmployeeID_FK)references employee(EmployeeID) on update CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;



CREATE TABLE `loan` (
  `LoanID` varchar(50)PRIMARY  KEY ,
  `CustomerNationalID_FK` varchar(50) NOT NULL,
  `EmployeeID_FK` varchar(50) NOT NULL,
  `loanStatus` varchar(50) NOT NULL DEFAULT 'Active',
  `RequestedAmount` double NOT NULL,
  `LoanQualityAssurance` double NOT NULL DEFAULT '0',
  `LoanInsurance` double NOT NULL DEFAULT '0',
  `LoanTax` double NOT NULL DEFAULT '0',
  `LoanDirectExpenses` double NOT NULL DEFAULT '0',
  `CashReceivable` double NOT NULL DEFAULT '0',
  `LoanInterest` double NOT NULL DEFAULT '0',
  `ActualDebt` double NOT NULL DEFAULT '0',
  `DateIssued` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (CustomerNationalID_FK)references  customer(CustomerNationaID) ON UPDATE CASCADE,
  FOREIGN KEY (EmployeeID_FK)references  employee(EmployeeID) ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;



CREATE TABLE `profitlossstatement` (
  `TotalCashReceivable` double NOT NULL DEFAULT '0',
  `TotalRequestedAmmount` double NOT NULL DEFAULT '0',
  `TotalInstallment` double NOT NULL DEFAULT '0',
  `TotalLoanInterest` double NOT NULL DEFAULT '0',
  `TotalIndirectBefDepreciation` double NOT NULL DEFAULT '0',
  `GrossProfit` double NOT NULL DEFAULT '0',
  `OperatingProfit` double NOT NULL DEFAULT '0',
  `ProfitBeforeTax` double NOT NULL DEFAULT '0',
  `Tax` double NOT NULL DEFAULT '0',
  `NetProfit` double NOT NULL DEFAULT '0',
  `InterestExpenses` double NOT NULL DEFAULT '0',
  `EmployeeID_FK` varchar(50) NOT NULL,
  `DateIssued` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `StatementID` int(11) PRIMARY KEY AUTO_INCREMENT,
  FOREIGN KEY(EmployeeID_FK)references employee(EmployeeID) on update CASCADE,
) ENGINE=InnoDB DEFAULT CHARSET=latin1;


create  trigger ComputeLoan
    before insert on loan
    for each  row
    begin
set new.LoanQualityAssurance=new.RequestedAmount*((select LoanQualityAssurance from charge)/100);
set new.LoanInsurance=new.RequestedAmount*((select LoanInsurance from charge)/100);
set new.LoanTax=new.RequestedAmount*((select charge.LoanTax from charge)/100);
set new.LoanDirectExpenses=new.RequestedAmount*((select charge.LoanDirectExpenses from charge)/100);
set new.CashReceivable=new.RequestedAmount-new.LoanQualityAssurance-new.LoanInsurance-new.LoanTax-new.LoanDirectExpenses;
set new.LoanInterest=new.RequestedAmount*((select charge.LoanInterest from charge)/100);
set new.ActualDebt=new.RequestedAmount+new.LoanInterest;
end $$

create  trigger ComputeInstallments
    before insert on installments
    for each  row
begin
if (select ActualDebt from loan where loan.LoanID=new.LoanId_FK)>new.InstalledAmount
then
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'insufficient installment';
else
update loan set loan.loanStatus='Completed' where loan.LoanID=new.LoanId_FK;
end if;
end $$

create trigger computeStatement
    before insert on profitlossstatement
    for each row
begin
    set new.TotalCashReceivable=(select sum(CashReceivable)from loan);
    set new.TotalRequestedAmmount=(select sum(RequestedAmount)from loan);
    set new.TotalInstallment=(select sum(InstalledAmount)from installments);
    set new.TotalLoanInterest=(select sum(LoanInterest)from loan);
    set new.TotalIndirectBefDepreciation=(select StatementIndirectCost from charge);
    set new.GrossProfit=new.TotalInstallment-(select sum(DirectCost)from charge);
    set new.OperatingProfit=new.GrossProfit-new.TotalIndirectBefDepreciation;
    set new.InterestExpenses=new.OperatingProfit*(select InterestExpenses from charge);
    set new.ProfitBeforeTax=new.OperatingProfit-new.InterestExpenses;
    set new.Tax=new.ProfitBeforeTax*(select LoanTax from charge);
    set new.NetProfit=new.ProfitBeforeTax-new.Tax;
end $$

create function login(username varchar(50), pass_word varchar(50))
returns text
begin
    if (select count(*) from customer where CustomerNationaID=username AND password=pass_word)>0
        then
        return 'welcome to dashboard';
        else
        return 'incorrect username or password';
    end if;
end $$


create procedure InsertCustomer(firstname varchar(50),lastname varchar(50),resident varchar(50),id varchar(50),addedby varchar(50),pass_word varchar(50))
insert into customer(FirstName, LastName, CustomerNationaID, Resident, password, AddedBy)
values (firstname,lastName,id,resident,pass_word,addedby);
end $$

create procedure  selectLoan()
select * from customer,installments,loan WHERE customer.CustomerNationaID=installments.CustomerNationalID_FK and customer.CustomerNationaID=loan.CustomerNationalID_FK;
END $$

create function insertLoan(loan_id varchar(50),Customer_id varchar(50),employee_id varchar(50),requested_amount real)
returns text
begin
if(select count(*)from loan where LoanID=loan_id)>0
then
return 'The Loan ID already Exist';
else
insert into loan(LoanID,CustomerNationaID,EmployeeID,RequestedAmmount)
values(loan_id,Customer_id,employee_id,requested_amount);
return 'Loan inserted';
end if;
end $$

create function insertInstallments(Loan_id int,Installment_number varchar (50),Customer_id varchar (50),installed_amount real,employee_id)
returns text
begin
insert into installments(LoanId_FK,InstallmentNumber,CustomerNationalID_FK,InstalledAmount,EmployeeID_FK)
values
(Loan_id,Installment_number,Customer_id,installed_amount,employee_id);
return 'Installments Successfully Added !';
end $$
