/*

Cleaning Data in SQL Queries

*/

Select *
From PortfolioProject.dbo.NashvilleHousing;


-------------------------------------------------------------------------------------------------------------------------
-- # Standardize Date Format

SELECT SaleDate, CONVERT(DATE, SaleDate)
From PortfolioProject.dbo.NashvilleHousing;

ALTER TABLE PortfolioProject.dbo.NashvilleHousing
ALTER COLUMN SaleDate DATE;


-------------------------------------------------------------------------------------------------------------------------
-- # 填充缺失的 PropertyAddress

-- 检查 PropertyAddress 列中的空值
SELECT *
From PortfolioProject.dbo.NashvilleHousing
WHERE PropertyAddress IS NULL;

-- 观察所有数据，以便理解其分布和潜在的重复模式
SELECT *
FROM PortfolioProject.dbo.NashvilleHousing
ORDER BY ParcelId;

-- 数据清洗前置验证：检查自连接逻辑和空值填充效果
	-- 通过自连接（基于相同的 ParcelId 但不同的 UniqueID）
	-- 查找可用于填充空 PropertyAddress 的匹配项。
SELECT 
	a.ParcelID, a.PropertyAddress, b.ParcelID, b.PropertyAddress,
	COALESCE(a.PropertyAddress, b.PropertyAddress) 
FROM PortfolioProject.dbo.NashvilleHousing a
JOIN PortfolioProject.dbo.NashvilleHousing b 
	ON a.ParcelId = b.ParcelId 
	AND a.UniqueId <> b.UniqueID
WHERE a.PropertyAddress IS NULL;

-- 执行填充操作：用相同 ParcelId、但 UniqueID 不同的记录中的 PropertyAddress，来填充当前 PropertyAddress 为 NULL 的记录
UPDATE a 
SET PropertyAddress = ISNULL(a.PropertyAddress, b.PropertyAddress) 
FROM PortfolioProject.dbo.NashvilleHousing a
JOIN PortfolioProject.dbo.NashvilleHousing b  
	ON a.ParcelId = b.ParcelId 
	AND a.UniqueId <> b.UniqueID  
WHERE a.PropertyAddress IS NULL;



-------------------------------------------------------------------------------------------------------------------------

-- # 解析并分离地址信息

-- 1. Splitting PropertyAddress into Address and City

-- 查看将要拆分的列，检查逻辑合理性
SELECT PropertyAddress
FROM PortfolioProject.dbo.NashvilleHousing;

SELECT 
 PropertyAddress,
 SUBSTRING(PropertyAddress, 1, CHARINDEX(',', PropertyAddress)-1) AS Address,
 CHARINDEX(',', PropertyAddress) AS separate_location,  
 SUBSTRING(PropertyAddress, CHARINDEX(',', PropertyAddress)+1, LEN(PropertyAddress)) AS City
FROM PortfolioProject.dbo.NashvilleHousing;

-- 在原始表中添加列，更新数据
ALTER TABLE PortfolioProject.dbo.NashvilleHousing
ADD Address VARCHAR(255), City VARCHAR(255);

UPDATE PortfolioProject.dbo.NashvilleHousing
SET 
	Address = SUBSTRING(PropertyAddress, 1, CHARINDEX(',', PropertyAddress)-1),
	City = SUBSTRING(PropertyAddress, CHARINDEX(',', PropertyAddress)+1, LEN(PropertyAddress));

SELECT * 
FROM PortfolioProject.dbo.NashvilleHousing;


-- 2.  Splitting OwnerAddress into Address、City and State
	-- 使用PARSENAME函数

-- 查看将要拆分的列，检查逻辑合理性
SELECT OwnerAddress 
FROM PortfolioProject.dbo.NashvilleHousing;

SELECT
	PARSENAME(REPLACE(OwnerAddress, ',', '.'), 3),  -- PARSENAME只能根据‘.’来解析字符串各部分，所以使用Replace函数将逗号修改为句点
	PARSENAME(REPLACE(OwnerAddress, ',', '.'), 2),
	PARSENAME(REPLACE(OwnerAddress, ',', '.'), 1)
FROM PortfolioProject.dbo.NashvilleHousing;

-- 添加列、更新数据
ALTER TABLE PortfolioProject..NashvilleHousing
ADD 
	OwnerSplitAddress VARCHAR(255),
	OwnerSplitCity VARCHAR(255),
	OwnerSplitState VARCHAR(255);
	
UPDATE PortfolioProject..NashvilleHousing
SET
	OwnerSplitAddress = PARSENAME(REPLACE(OwnerAddress, ',', '.'), 3),
	OwnerSplitCity = 	PARSENAME(REPLACE(OwnerAddress, ',', '.'), 2),
	OwnerSplitState = PARSENAME(REPLACE(OwnerAddress, ',', '.'), 1);

SELECT * FROM NashvilleHousing;


-------------------------------------------------------------------------------------------------------------------------


-- # 统一 'SoldAsVacant' 列中的值，将 'Y' 转换为 'Yes'，'N' 转换为 'No'

-- 检查 'SoldAsVacant' 列的当前分布情况
SELECT DISTINCT SoldAsVacant, COUNT(SoldAsVacant)
FROM PortfolioProject..NashvilleHousing
GROUP BY SoldAsVacant
ORDER BY 2;

-- 预览转换逻辑的效果
SELECT SoldAsVacant,
CASE 
	WHEN SoldAsVacant = 'Y' THEN 'Yes'
	WHEN SoldAsVacant = 'N' THEN 'No'
	ELSE SoldAsVacant
END
FROM PortfolioProject..NashvilleHousing
ORDER BY SoldAsVacant;

-- 修改表中数据
UPDATE PortfolioProject..NashvilleHousing
SET              
	SoldAsVacant =  CASE 
	WHEN SoldAsVacant = 'Y' THEN 'Yes'
	WHEN SoldAsVacant = 'N' THEN 'No'
	ELSE SoldAsVacant
END;


-------------------------------------------------------------------------------------------------------------------------

-- # Delete duplicates

-- 识别重复行
-- 通过 ROW_NUMBER() 对基于关键列（除 UniqueID 外）的重复数据进行分区编号。
-- row_num > 1 的行即为重复数据。
SELECT
	*,
	row_number ( ) OVER ( PARTITION BY ParcelID, PropertyAddress, SalePrice, SaleDate, LegalReference ORDER BY UniqueID ) row_num 
FROM
	NashvilleHousing 
ORDER BY
	ParcelID

-- 使用 CTE 过滤并（选择性地）删除重复行：
-- CTE (DuplicatesCTE) 用于计算行号，便于后续过滤。
WITH DuplicatesCTE AS (
	SELECT
		*,
		row_number ( ) OVER ( PARTITION BY ParcelID, PropertyAddress, SalePrice, SaleDate, LegalReference, OwnerName, OwnerAddress, Acreage, TaxDistrict, LandValue ORDER BY UniqueID ) AS row_num 
	FROM
		NashvilleHousing 
	)
-- --------------------------------------------------------------------------------------
-- 选项 A: 预览待删除的重复行
/*
 SELECT *
 FROM DuplicatesCTE
 WHERE row_num > 1;
*/
-- --------------------------------------------------------------------------------------
-- 选项 B: 计数待删除的重复行
/*
SELECT COUNT(*) AS NumberOfDuplicates
FROM DuplicatesCTE
WHERE row_num > 1;
*/
-- --------------------------------------------------------------------------------------
-- 选项 C: 执行删除操作 (此操作不可逆)
/*
DELETE
FROM DuplicatesCTE
WHERE row_num > 1;
*/


-------------------------------------------------------------------------------------------------------------------------

-- # Delete unused columns 

SELECT * FROM NashvilleHousing;

ALTER TABLE NashvilleHousing
DROP COLUMN OwnerAddress, TaxDistrict, PropertyAddress;

