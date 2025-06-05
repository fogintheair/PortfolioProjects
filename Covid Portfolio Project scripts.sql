SELECT * 
FROM PortfolioProject..CovidDeaths 
WHERE continent IS NOT NULL 
ORDER BY 3,4 

-- select data that we are going to be using
SELECT
	location, [date], total_cases, new_cases, total_deaths, population 
FROM
	PortfolioProject..CovidDeaths 
ORDER BY 1,2
	
-- looking at total_cases VS total_deaths
-- 美国总病例、总死亡数、死亡率
SELECT
	location, [date], total_cases, total_deaths,
	total_deaths * 100.0 / NULLIF ( total_cases , 0 ) AS deathpercentage --转换为浮点数避免自动截断
FROM
	PortfolioProject..CovidDeaths 
WHERE
	location LIKE '%states%' 
ORDER BY 1,2 
	
-- 中国总病例、总死亡数、死亡率
SELECT
	location, [date], total_cases, total_deaths,
	total_deaths  * 100.0 / NULLIF ( total_cases, 0 ) AS deathpercentage 
FROM
	PortfolioProject..CovidDeaths 
WHERE
	location = 'China' 
ORDER BY 1,2 
	
-- 查看各地区总病例与总人口比率
SELECT
	location, [date], population, total_cases,
	total_cases * 100.0 / NULLIF ( population , 0 ) AS infection_rate 
FROM
	PortfolioProject..CovidDeaths 
-- WHERE location='China'
ORDER BY 1,2

-- 查询每个国家/地区的最高感染人数、最高感染率。
SELECT
	location, population,
	MAX ( total_cases ) AS highestInfectionCount,
	MAX ( total_cases * 100.0 / NULLIF ( population , 0 ) )  AS infection_rate 
FROM
	PortfolioProject..CovidDeaths 
GROUP BY
	location,
	population 
ORDER BY
	infection_rate DESC;

-- 有关每个国家/地区的最高死亡人数
SELECT
	location,
	MAX ( total_deaths ) AS TotalDeathCount 
FROM
	PortfolioProject..CovidDeaths 
WHERE
	continent IS NOT NULL  -- 当continent为null时，location是州名，若省略此句，会导致重复计算的问题。
GROUP BY
	location 
ORDER BY
	TotalDeathCount DESC;
/*
当total_deaths为VARCHAR类型时，MAX()函数会按照字典顺序（字符串排序）而不是数值大小来找出最大值；
若出现上述问题，需要将其转换为int类型：MAX(CAST(total_deaths AS int))
若字段包含非数字字符，如N/A，直接使用CAST函数会报错，需要使用TRY_CAST或CASE WHEN ISNUMBERIC()处理：
SELECT 
    location, 
    MAX(CASE WHEN ISNUMERIC(total_deaths)=1   -- ISNUMBERIC(total_deaths):检查字符串是否可以转换为数字，返回1即可转换
             THEN CAST(total_deaths AS INT)   -- 可转换（ISNUMBERIC=1），执行CAST，否则返回NULL
             ELSE NULL END) AS TotalDeathCount
FROM PortfolioProject..CovidDeaths
GROUP BY location
ORDER BY TotalDeathCount DESC;
*/

-- LET'S BREAK THING DOWN BY CONTINENT

-- 查看每个州的情况：每个州最高死亡数
-- 方法一：
SELECT
	continent,
	MAX ( total_deaths ) AS TotalDeathCount 
FROM
	PortfolioProject..CovidDeaths 
WHERE
	continent IS NOT NULL 
GROUP BY
	continent 
ORDER BY
	TotalDeathCount DESC;


-- global numbers

-- 累计死亡率趋势（基于总数据）
-- 显示截止当日的累计总数，理论上单调递增，查看疫情总体规模
-- 每日累计死亡率（总死亡/总病例）
SELECT
	[date],
	SUM ( total_cases ) AS cumulative_cases,
	SUM ( total_deaths ) AS cumulative_deaths,
	SUM ( total_deaths ) * 100.0 / SUM ( total_cases ) AS deathpercentage 
FROM
	PortfolioProject..CovidDeaths 
WHERE
	continent IS NOT NULL 	
GROUP BY
	[date] 
ORDER BY
	1,2 

-- 每日死亡率趋势（基于新增数据）
-- 显示当日新增数量(世界各个国家每日新增总和)，显示每日波动，反映疫情变化，分析每日疫情发展态势。
-- 每日死亡率（新增死亡/新增病例）
SELECT
	[date],
	SUM ( new_cases ) AS DailyCases,
	SUM ( new_deaths ) AS DailyDeaths,
	SUM ( new_deaths ) * 100.0 / NULLIF ( SUM ( new_cases ), 0 ) AS DeathPercentageDaily 
FROM
	PortfolioProject..CovidDeaths 
--WHERE location='China'
WHERE
	continent IS NOT NULL 
GROUP BY
	[date] 
ORDER BY
	1,2 
	


-- 计算样本期间内全球Covid-19死亡比率

-- 基于每日新增数据，累加计算样本期间内总体死亡率
SELECT 
	SUM(new_cases) AS cumulative_new_cases,
	SUM(new_deaths) AS cumulative_new_deaths,
	SUM(new_deaths)*100.0 / NULLIF(SUM(new_cases), 0) AS DeathPercentage
FROM PortfolioProject..CovidDeaths
WHERE continent IS NOT NULL  

-- 基于最新各地累计值计算总死亡率，对比每日累加
WITH LatestData AS (
    SELECT
      location,
      total_cases,
      total_deaths,
      ROW_NUMBER() OVER (PARTITION BY location ORDER BY date DESC) AS rn
    FROM PortfolioProject..CovidDeaths
    WHERE continent IS NOT NULL
)
-- 只保留 rn = 1（即每个 location 最新那行）
, TotalByLocation AS (
    SELECT
      'By Location (Latest Records)' AS MetricType,
      SUM(total_cases) AS TotalCases,
      SUM(total_deaths) AS TotalDeaths,
      SUM(total_deaths) * 100.0 / NULLIF(SUM(total_cases), 0) AS DeathPercentage
    FROM LatestData
    WHERE rn = 1
)
, TotalByDate AS (
    SELECT
      'By Day (Sum of Daily Cases)' AS MetricType,
      SUM(new_cases) AS TotalCases,
      SUM(new_deaths) AS TotalDeaths,
      SUM(new_deaths) * 100.0 / NULLIF(SUM(new_cases), 0) AS DeathPercentage
    FROM PortfolioProject..CovidDeaths
    WHERE continent IS NOT NULL
)
SELECT MetricType, TotalCases, TotalDeaths, DeathPercentage
FROM TotalByLocation
UNION ALL
SELECT MetricType, TotalCases, TotalDeaths, DeathPercentage
FROM TotalByDate;


-- 连接两张表
SELECT
	* 
FROM
	PortfolioProject..CovidDeaths dea
	JOIN PortfolioProject..CovidVaccinations vac ON dea.location = vac.location 
	AND dea.date = vac.date;

-- 总人口与新疫苗接种数
SELECT
	dea.continent,
	dea.location,
	dea.date,
	dea.population,
	vac.new_vaccinations 
FROM
	PortfolioProject..CovidDeaths dea
	JOIN PortfolioProject..CovidVaccinations vac ON dea.location = vac.location 
	AND dea.date = vac.date 
WHERE
	dea.continent IS NOT NULL 
ORDER BY
	dea.location,
	dea.date;

-- 计算各国每日新增疫苗接种的滚动累计值
-- 同时保留人口字段，方便后续计算接种覆盖率或绘制随时间变化趋势图
SELECT
	dea.continent,
	dea.location,
	dea.date,
	dea.population,
	vac.new_vaccinations,
	SUM ( vac.new_vaccinations ) OVER ( partition BY dea.location ORDER BY dea.date ) AS cumulative_new_vac 
FROM
	PortfolioProject..CovidDeaths dea
	JOIN PortfolioProject..CovidVaccinations vac ON dea.location = vac.location 
	AND dea.[date] = vac.[date] 
WHERE
	dea.continent IS NOT NULL 
ORDER BY
	2, 3;


-- 计算各国每日滚动疫苗接种率（即每一天各国累计接种人数占总人口比例）

-- 方法一：使用CTE（公用表表达式）
-- 步骤说明：
--   1. 在 CTE 中先按国家和日期累加“每日新增接种”得到“当前累计接种”；
--   2. 再在主查询中将“当前累计接种”除以“人口数”，得到每日的接种覆盖率。
WITH cumulative_vac AS (
	SELECT
		dea.continent,
		dea.location,
		dea.date,
		dea.population,
		vac.new_vaccinations,
		SUM ( vac.new_vaccinations ) OVER ( partition BY dea.location ORDER BY dea.date ) AS cumulative_new_vac 
	FROM
		PortfolioProject..CovidDeaths dea
		JOIN PortfolioProject..CovidVaccinations vac ON dea.location = vac.location 
		AND dea.[date] = vac.[date] 
	WHERE
		dea.continent IS NOT NULL 
	) 
	
SELECT
	*,
	cumulative_new_vac * 100.0 / population AS RollingPeopleVaccinated 
FROM
	cumulative_vac 
ORDER BY
	location, [date];

-- 方法二：创建临时表
DROP TABLE IF EXISTS #PercentPopulationVaccinated 
CREATE TABLE #PercentPopulationVaccinated 
( 
	continent nvarchar ( 255 ), 
	location nvarchar ( 255 ), 
	DATE datetime, 
	population NUMERIC, 
	new_vaccinations NUMERIC, 
	RollingPeopleVaccinated NUMERIC 
	) 
	
INSERT INTO #PercentPopulationVaccinated 
SELECT
	dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
	SUM ( vac.new_vaccinations ) OVER ( partition BY dea.location ORDER BY dea.date ) AS RollingPeopleVaccinated 
FROM
	PortfolioProject..CovidDeaths dea
	JOIN PortfolioProject..CovidVaccinations vac ON dea.location = vac.location 
	AND dea.[date] = vac.[date] 
-- WHERE dea.continent IS NOT NULL
-- ORDER BY 2,3

SELECT
	*,
	RollingPeopleVaccinated *100.0 / population AS RollingPeopleVaccinatedRate 
FROM #PercentPopulationVaccinated 
WHERE continent IS NOT NULL 
ORDER BY 2,3;
	
-- 方法三：创建视图
-- creating VIEW to store data for later visualizations
CREATE VIEW PercentPopulationVaccinated AS 
SELECT
	dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
	SUM ( vac.new_vaccinations ) OVER ( partition BY dea.location ORDER BY dea.date ) AS RollingPeopleVaccinated 
FROM
	PortfolioProject..CovidDeaths dea
	JOIN PortfolioProject..CovidVaccinations vac ON dea.location = vac.location 
	AND dea.[date] = vac.[date] 
WHERE dea.continent IS NOT NULL 
-- ORDER BY 2,3 -- 再一次，视图中不可以使用order by子句

SELECT * 
FROM PercentPopulationVaccinated;

SELECT *,
	new_vaccinations / population * 100 AS RollingPeopleVaccinatedRate 
FROM PercentPopulationVaccinated 
ORDER BY 2,3;

-- 计算各国家/地区疫苗接种率（使用cumulative_new_vac字段的最大值）
-- 基于视图
SELECT
	continent, location, population,
	MAX ( RollingPeopleVaccinated ) AS total_vac,
	MAX ( RollingPeopleVaccinated ) * 100.0 / population AS vac_rate 
FROM PercentPopulationVaccinated 
GROUP BY continent, location, population 
ORDER BY continent, location;
	
	
	
	