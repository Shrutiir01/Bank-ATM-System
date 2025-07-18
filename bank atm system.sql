--1.Table Creation

CREATE TABLE Customers(AccountNumber NUMBER PRIMARY KEY
                      ,CustomerName  VARCHAR2(100)
                      ,PIN           NUMBER(4)
                      ,Balance       NUMBER(10,2)
                      );
                      
CREATE TABLE Transactions (TransID       NUMBER PRIMARY KEY
                          ,AccountNumber NUMBER
                          ,TransType     VARCHAR2(20)
                          ,Amount        NUMBER(10,2)
                          ,TransDate     DATE
                          ,CONSTRAINTS Transactions_TransID_fk FOREIGN KEY (AccountNumber) 
                                                               REFERENCES Customers(AccountNumber)
                          );
--2. Creating Sequence

CREATE SEQUENCE Trans_SEQ
START WITH 1
INCREMENT BY 1
NOCACHE
NOCYCLE
;

--3.Insert Operation
----To Add Values
INSERT INTO Customers VALUES (1001, 'Ramesh', 1234, 5000);
INSERT INTO Customers VALUES (1002, 'Deep', 4321, 10000);
INSERT INTO Customers VALUES (1003, 'Suresh', 1111, 7500);
INSERT INTO Customers VALUES (1004, 'Sita', 1452, 25000);
INSERT INTO Customers VALUES (1005, 'Sahil', 2541, 30000);
INSERT INTO Customers VALUES (1006, 'Mina', 2222, 75000);

--4.Data Retrieval
----To fetch data
SELECT *
FROM   Customers

--5.Creating Procedure
---To Withdraw Amount

CREATE OR REPLACE PROCEDURE Withdraw_Amount
(p_AccNo  IN NUMBER
,p_PIN    IN NUMBER
,p_Amount IN NUMBER
)
AS
  v_Balance NUMBER;
  v_PIN     NUMBER;
BEGIN
    SELECT PIN 
          ,Balance
    INTO  v_PIN 
         ,v_Balance
    FROM  Customers
    WHERE AccountNumber = p_AccNo
    ;

    IF v_PIN != p_PIN
    THEN
      RAISE_APPLICATION_ERROR(-20001, 'Invalid PIN');
    ELSIF p_Amount > v_Balance
    THEN
      RAISE_APPLICATION_ERROR(-20002, 'Insufficient Balance');
    ELSE
      UPDATE Customers
      SET    Balance = Balance - p_Amount 
      WHERE  AccountNumber = p_AccNo
      ;

        INSERT INTO Transactions(TransID
                                ,AccountNumber
                                ,TransType
                                ,Amount
                                ,TransDate
                                )
        VALUES                  (Trans_SEQ.NEXTVAL
                                ,p_AccNo
                                ,'Withdraw'
                                ,p_Amount
                                ,SYSDATE
                                );
    END IF;
END;

----To Deposit Amount
CREATE OR REPLACE PROCEDURE Deposit_Amount
(p_AccNo IN NUMBER
,p_Amount IN NUMBER
)
AS
BEGIN
    UPDATE Customers
    SET    Balance = Balance + p_Amount
    WHERE  AccountNumber = p_AccNo
    ;

    INSERT INTO Transactions(TransID
                            ,AccountNumber
                            ,TransType
                            ,Amount
                            ,TransDate
                            )
    VALUES                  (Trans_SEQ.NEXTVAL
                            ,p_AccNo
                            ,'Deposit'
                            ,p_Amount
                            ,SYSDATE
                            );
END;


----To get Mini Statement

CREATE OR REPLACE PROCEDURE Mini_Statement
(p_AccNo IN NUMBER
)
AS
BEGIN
  FOR rec IN (SELECT *
              FROM (SELECT *
                    FROM Transactions
                    WHERE AccountNumber = p_AccNo
                    ORDER BY TransDate DESC
                   )
              WHERE ROWNUM <= 5
             )
  LOOP
    DBMS_OUTPUT.PUT_LINE(rec.TransDate || ' - ' || rec.TransType || ': ' || rec.Amount);
  END LOOP;
END;
   
--7.Creating Function
----To Check Balance

CREATE OR REPLACE FUNCTION Get_Balance
(p_AccNo IN NUMBER
,p_PIN IN NUMBER
)
RETURN NUMBER
AS
  v_PIN NUMBER;
  v_Balance NUMBER;
BEGIN
    SELECT PIN
          ,Balance 
    INTO   v_PIN
          ,v_Balance 
    FROM   Customers 
    WHERE  AccountNumber = p_AccNo
    ;

    IF v_PIN != p_PIN 
    THEN
      RAISE_APPLICATION_ERROR(-20001, 'Invalid PIN');
    END IF;
    RETURN v_Balance;
END;


--8.Creating Triggers
----a)High-Value Withdrawal Alert
----This trigger activates after a withdrawal is recorded and alerts if the amount exceeds ₹5000.

CREATE OR REPLACE TRIGGER trg_HighWithdrawal
AFTER INSERT ON Transactions
FOR EACH ROW
WHEN (NEW.TransType = 'Withdraw' AND NEW.Amount > 5000)
BEGIN
    DBMS_OUTPUT.PUT_LINE('Alert: High-value withdrawal of ' || :NEW.Amount || ' from account ' || :NEW.AccountNumber);
END;

 
----b)Prevent Negative Balance (extra safety)

CREATE OR REPLACE TRIGGER trg_NoNegativeBalance
BEFORE UPDATE ON Customers
FOR EACH ROW
BEGIN
    IF :NEW.Balance < 0 THEN
        RAISE_APPLICATION_ERROR(-20003, 'Transaction would result in negative balance.');
    END IF;
END;


----c)To detect suspicious activity: more than 3 withdrawals in a day

CREATE OR REPLACE TRIGGER trg_SuspiciousWithdrawals
AFTER INSERT ON Transactions
FOR EACH ROW
WHEN (NEW.TransType = 'Withdraw')
DECLARE
    v_Count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_Count
    FROM Transactions
    WHERE AccountNumber = :NEW.AccountNumber
      AND TransType = 'Withdraw'
      AND TRUNC(TransDate) = TRUNC(SYSDATE);

    IF v_Count > 3 THEN
        INSERT INTO TriggerLog (AccountNumber, Message)
        VALUES (:NEW.AccountNumber, 'Suspicious activity: more than 3 withdrawals today');
    END IF;
END;


--9.TESTING

----Withdraw
DECLARE
  v_accno  NUMBER(10) := 1001;
  v_amount NUMBER(10) := 1500;
  v_pin    customers.pin%TYPE;
BEGIN
  SELECT pin
  INTO   v_pin
  FROM   Customers
  WHERE  accountnumber = v_accno
  ;
  Withdraw_Amount(v_accno
                 ,v_PIN
                 ,v_Amount
                 );
END;
---------
BEGIN
    Withdraw_Amount(1001, 1234, 1000);
END;

----Deposit
DECLARE
  v_AccNo  NUMBER(10):= 1003;
  v_Amount NUMBER(10):= 1000;
BEGIN
    Deposit_Amount(v_AccNo
                  ,v_Amount
                  );
END;

----Mini Statement
BEGIN
    Mini_Statement(1001);
END;

----Check Balance

SELECT Get_Balance(1001, 1234) 
FROM   dual;
