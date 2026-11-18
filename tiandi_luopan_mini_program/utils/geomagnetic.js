/**
 * geomagnetic.js
 * 纯 JS 离线全球地磁模型（算法与 iOS WorldMagneticModel.swift 对齐）
 * 基于 NOAA / NCEI World Magnetic Model (WMM 2025-2030，epoch 2025.0)
 * 无需联网，输入经纬度、海拔及时间，离线解算：
 *   磁偏角 Declination / 磁倾角 Inclination / 磁场总强度 FieldStrength
 *   水平强度 HorizontalStrength / 北向 X / 东向 Y / 垂直 Z
 */

const G_COEFF = [
  [0.0],
  [-29351.8, -1410.8],
  [-2556.6, 2951.1, 1649.3],
  [1361.0, -2404.1, 1243.8, 453.6],
  [895.0, 799.5, 55.7, -281.1, 12.1],
  [-233.2, 368.9, 187.2, -138.7, -142.0, 20.9],
  [64.4, 63.8, 76.9, -115.7, -40.9, 14.9, -60.7],
  [79.5, -77.0, -8.8, 59.3, 15.8, 2.5, -11.1, 14.2],
  [23.2, 10.8, -17.5, 2.0, -21.7, 16.9, 15.0, -16.8, 0.9],
  [4.6, 7.8, 3.0, -0.2, -2.5, -13.1, 2.4, 8.6, -8.7, -12.9],
  [-1.3, -6.4, 0.2, 2.0, -1.0, -0.6, -0.9, 1.5, 0.9, -2.7, -3.9],
  [2.9, -1.5, -2.5, 2.4, -0.6, -0.1, -0.6, -0.1, 1.1, -1.0, -0.2, 2.6],
  [-2.0, -0.2, 0.3, 1.2, -1.3, 0.6, 0.6, 0.5, -0.1, -0.4, -0.2, -1.3, -0.7]
];

const H_COEFF = [
  [0.0],
  [0.0, 4545.4],
  [0.0, -3133.6, -815.1],
  [0.0, -56.6, 237.5, -549.5],
  [0.0, 278.6, -133.9, 212.0, -375.6],
  [0.0, 45.4, 220.2, -122.9, 43.0, 106.1],
  [0.0, -18.4, 16.8, 48.8, -59.8, 10.9, 72.7],
  [0.0, -48.9, -14.4, -1.0, 23.4, -7.4, -25.1, -2.3],
  [0.0, 7.1, -12.6, 11.4, -9.7, 12.7, 0.7, -5.2, 3.9],
  [0.0, -24.8, 12.2, 8.3, -3.3, -5.2, 7.2, -0.6, 0.8, 10.0],
  [0.0, 3.3, 0.0, 2.4, 5.3, -9.1, 0.4, -4.2, -3.8, 0.9, -9.1],
  [0.0, 0.0, 2.9, -0.6, 0.2, 0.5, -0.3, -1.2, -1.7, -2.9, -1.8, -2.3],
  [0.0, -1.3, 0.7, 1.0, -1.4, -0.0, 0.6, -0.1, 0.8, 0.1, -1.0, 0.1, 0.2]
];

const DELTA_G = [
  [0.0],
  [12.0, 9.7],
  [-11.6, -5.2, -8.0],
  [-1.3, -4.2, 0.4, -15.6],
  [-1.6, -2.4, -6.0, 5.6, -7.0],
  [0.6, 1.4, 0.0, 0.6, 2.2, 0.9],
  [-0.2, -0.4, 0.9, 1.2, -0.9, 0.3, 0.9],
  [-0.0, -0.1, -0.1, 0.5, -0.1, -0.8, -0.8, 0.8],
  [-0.1, 0.2, 0.0, 0.5, -0.1, 0.3, 0.2, -0.0, 0.2],
  [-0.0, -0.1, 0.1, 0.3, -0.3, 0.0, 0.3, -0.1, 0.1, -0.1],
  [0.1, 0.0, 0.1, 0.1, -0.0, -0.3, 0.0, -0.1, -0.1, -0.0, -0.0],
  [0.0, -0.0, 0.0, 0.0, 0.0, -0.1, 0.0, -0.0, -0.1, -0.1, -0.1, -0.1],
  [0.0, 0.0, -0.0, -0.0, -0.0, -0.0, 0.1, -0.0, 0.0, 0.0, -0.1, -0.0, -0.1]
];

const DELTA_H = [
  [0.0],
  [0.0, -21.5],
  [0.0, -27.7, -12.1],
  [0.0, 4.0, -0.3, -4.1],
  [0.0, -1.1, 4.1, 1.6, -4.4],
  [0.0, -0.5, 2.2, 0.4, 1.7, 1.9],
  [0.0, 0.3, -1.6, -0.4, 0.9, 0.7, 0.9],
  [0.0, 0.6, 0.5, -0.8, 0.0, -1.0, 0.6, -0.2],
  [0.0, -0.2, 0.5, -0.4, 0.4, -0.5, -0.6, 0.3, 0.2],
  [0.0, -0.3, 0.3, -0.3, 0.3, 0.2, -0.1, -0.2, 0.4, 0.1],
  [0.0, 0.0, -0.0, -0.2, 0.1, -0.1, 0.1, 0.0, -0.1, 0.2, -0.0],
  [0.0, -0.0, 0.1, -0.0, 0.1, -0.0, -0.0, 0.1, -0.0, 0.0, 0.0, 0.0],
  [0.0, -0.0, 0.0, -0.1, 0.1, -0.0, -0.0, -0.0, 0.0, -0.0, -0.0, 0.0, -0.1]
];

const BASE_TIME = Date.UTC(2025, 0, 1);
const EARTH_SEMI_MAJOR_AXIS_KM = 6378.137;
const EARTH_SEMI_MINOR_AXIS_KM = 6356.7523142;
const EARTH_REFERENCE_RADIUS_KM = 6371.2;

function computeSchmidtQuasiNormFactors(maxN) {
  const factors = [];
  factors[0] = [1.0];
  for (let n = 1; n <= maxN; n++) {
    factors[n] = new Float32Array(n + 1);
    factors[n][0] = factors[n - 1][0] * (2 * n - 1) / n;
    for (let m = 1; m <= n; m++) {
      factors[n][m] = factors[n][m - 1] * Math.sqrt((n - m + 1) * (m === 1 ? 2 : 1) / (n + m));
    }
  }
  return factors;
}

const SCHMIDT_FACTORS = computeSchmidtQuasiNormFactors(G_COEFF.length);

class LegendreTable {
  constructor(maxN, thetaRad) {
    const cos = Math.cos(thetaRad);
    const sin = Math.sin(thetaRad);
    this.mP = [];
    this.mPDeriv = [];
    this.mP[0] = [1.0];
    this.mPDeriv[0] = [0.0];
    for (let n = 1; n <= maxN; n++) {
      this.mP[n] = new Float32Array(n + 1);
      this.mPDeriv[n] = new Float32Array(n + 1);
      for (let m = 0; m <= n; m++) {
        if (n === m) {
          this.mP[n][m] = sin * this.mP[n - 1][m - 1];
          this.mPDeriv[n][m] = cos * this.mP[n - 1][m - 1] + sin * this.mPDeriv[n - 1][m - 1];
        } else if (n === 1 || m === n - 1) {
          this.mP[n][m] = cos * this.mP[n - 1][m];
          this.mPDeriv[n][m] = -sin * this.mP[n - 1][m] + cos * this.mPDeriv[n - 1][m];
        } else {
          const k = ((n - 1) * (n - 1) - m * m) / ((2 * n - 1) * (2 * n - 3));
          this.mP[n][m] = cos * this.mP[n - 1][m] - k * this.mP[n - 2][m];
          this.mPDeriv[n][m] = -sin * this.mP[n - 1][m] + cos * this.mPDeriv[n - 1][m] - k * this.mPDeriv[n - 2][m];
        }
      }
    }
  }
}

function normalizeTimeMillis(timeMillis) {
  if (typeof timeMillis === 'object' && timeMillis !== null && timeMillis.getTime) {
    return timeMillis.getTime();
  }
  return Number(timeMillis);
}

/**
 * 完整解算任意坐标点的地磁七要素
 * @param {number} gdLatitudeDeg 纬度 (-90 ~ 90)
 * @param {number} gdLongitudeDeg 经度 (-180 ~ 180)
 * @param {number} altitudeMeters 海拔 (m)
 * @param {Date|number} timeMillis 评估时间点
 * @returns {{x:number, y:number, z:number, declination:number, inclination:number,
 *            horizontalStrength:number, fieldStrength:number}}
 *          分量单位为 nT；角度单位为度（磁偏角负=西偏，正=东偏）
 */
function computeGeomagneticField(gdLatitudeDeg, gdLongitudeDeg, altitudeMeters = 0, timeMillis = Date.now()) {
  timeMillis = normalizeTimeMillis(timeMillis);

  gdLatitudeDeg = Number.isFinite(Number(gdLatitudeDeg)) ? Number(gdLatitudeDeg) : 0;
  gdLatitudeDeg = Math.min(90.0 - 1e-5, Math.max(-90.0 + 1e-5, gdLatitudeDeg));
  // Core Location 通常给 [-180,180]，但调用方也可能传入展开后的经度。
  // 与 iOS WorldMagneticModel 一致：先归一化再求谐波，避免大数导致 sin/cos 精度损失。
  const rawLon = Number.isFinite(Number(gdLongitudeDeg)) ? Number(gdLongitudeDeg) : 0;
  const wrappedLon = rawLon % 360.0;
  gdLongitudeDeg = wrappedLon > 180.0 ? wrappedLon - 360.0
    : (wrappedLon < -180.0 ? wrappedLon + 360.0 : wrappedLon);
  const altitudeKm = (Number(altitudeMeters) || 0) / 1000.0;

  const a2 = EARTH_SEMI_MAJOR_AXIS_KM * EARTH_SEMI_MAJOR_AXIS_KM;
  const b2 = EARTH_SEMI_MINOR_AXIS_KM * EARTH_SEMI_MINOR_AXIS_KM;
  const gdLatRad = gdLatitudeDeg * Math.PI / 180.0;
  const clat = Math.cos(gdLatRad);
  const slat = Math.sin(gdLatRad);
  const tlat = slat / clat;
  const latRad = Math.sqrt(a2 * clat * clat + b2 * slat * slat);

  const mGcLatitudeRad = Math.atan(tlat * (latRad * altitudeKm + b2) / (latRad * altitudeKm + a2));
  const mGcLongitudeRad = gdLongitudeDeg * Math.PI / 180.0;
  const radSq = altitudeKm * altitudeKm
    + 2 * altitudeKm * Math.sqrt(a2 * clat * clat + b2 * slat * slat)
    + (a2 * a2 * clat * clat + b2 * b2 * slat * slat) / (a2 * clat * clat + b2 * slat * slat);
  const mGcRadiusKm = Math.sqrt(radSq);

  const MAX_N = G_COEFF.length;
  const legendre = new LegendreTable(MAX_N - 1, Math.PI / 2.0 - mGcLatitudeRad);

  const relativeRadiusPower = new Float32Array(MAX_N + 2);
  relativeRadiusPower[0] = 1.0;
  relativeRadiusPower[1] = EARTH_REFERENCE_RADIUS_KM / mGcRadiusKm;
  for (let i = 2; i < relativeRadiusPower.length; ++i) {
    relativeRadiusPower[i] = relativeRadiusPower[i - 1] * relativeRadiusPower[1];
  }

  const sinMLon = new Float32Array(MAX_N);
  const cosMLon = new Float32Array(MAX_N);
  sinMLon[0] = 0.0;
  cosMLon[0] = 1.0;
  sinMLon[1] = Math.sin(mGcLongitudeRad);
  cosMLon[1] = Math.cos(mGcLongitudeRad);
  for (let m = 2; m < MAX_N; ++m) {
    const x = m >> 1;
    sinMLon[m] = sinMLon[m - x] * cosMLon[x] + cosMLon[m - x] * sinMLon[x];
    cosMLon[m] = cosMLon[m - x] * cosMLon[x] - sinMLon[m - x] * sinMLon[x];
  }

  const inverseCosLatitude = 1.0 / Math.cos(mGcLatitudeRad);
  // WMM 长期变化系数以儒略年（365.25 天）为单位；用 365 天会逐年累积误差。
  const yearsSinceBase = (timeMillis - BASE_TIME) / (365.25 * 24 * 60 * 60 * 1000);

  let gcX = 0.0;
  let gcY = 0.0;
  let gcZ = 0.0;

  for (let n = 1; n < MAX_N; n++) {
    for (let m = 0; m <= n; m++) {
      const g = G_COEFF[n][m] + yearsSinceBase * DELTA_G[n][m];
      const h = H_COEFF[n][m] + yearsSinceBase * DELTA_H[n][m];

      gcX += relativeRadiusPower[n + 2]
        * (g * cosMLon[m] + h * sinMLon[m])
        * legendre.mPDeriv[n][m]
        * SCHMIDT_FACTORS[n][m];

      gcY += relativeRadiusPower[n + 2] * m
        * (g * sinMLon[m] - h * cosMLon[m])
        * legendre.mP[n][m]
        * SCHMIDT_FACTORS[n][m]
        * inverseCosLatitude;

      gcZ -= (n + 1) * relativeRadiusPower[n + 2]
        * (g * cosMLon[m] + h * sinMLon[m])
        * legendre.mP[n][m]
        * SCHMIDT_FACTORS[n][m];
    }
  }

  // 地心坐标 → 大地坐标：绕 Y 轴旋转 latDiff 角
  // 严格对齐 AOSP GeomagneticField 构造器：
  //   mX =  gcX*cos(latDiff) + gcZ*sin(latDiff)
  //   mY =  gcY
  //   mZ = -gcX*sin(latDiff) + gcZ*cos(latDiff)
  const latDiffRad = gdLatRad - mGcLatitudeRad;
  const x = gcX * Math.cos(latDiffRad) + gcZ * Math.sin(latDiffRad);
  const y = gcY;
  const z = -gcX * Math.sin(latDiffRad) + gcZ * Math.cos(latDiffRad);

  const horizontalStrength = Math.sqrt(x * x + y * y);
  const fieldStrength = Math.sqrt(x * x + y * y + z * z);

  return {
    x, y, z,                                                       // nT：北向 / 东向 / 垂直向下
    declination: Math.atan2(y, x) * 180.0 / Math.PI,               // 磁偏角（负=西偏）
    inclination: Math.atan2(z, horizontalStrength) * 180.0 / Math.PI, // 磁倾角
    horizontalStrength,
    fieldStrength
  };
}

/**
 * 计算地磁偏角（度，负数=西偏，正数=东偏），保留一位小数
 */
function computeDeclination(gdLatitudeDeg, gdLongitudeDeg, altitudeMeters = 0, timeMillis = Date.now()) {
  const f = computeGeomagneticField(gdLatitudeDeg, gdLongitudeDeg, altitudeMeters, timeMillis);
  return Math.round(f.declination * 10) / 10;
}

/**
 * 计算磁场总强度（μT）
 */
function computeFieldStrength(gdLatitudeDeg, gdLongitudeDeg, altitudeMeters = 0, timeMillis = Date.now()) {
  const f = computeGeomagneticField(gdLatitudeDeg, gdLongitudeDeg, altitudeMeters, timeMillis);
  return Math.round((f.fieldStrength / 1000) * 10) / 10; // nT → μT
}

/**
 * 格式化输出偏角与坐标描述
 */
function formatLocationAndDeclination(latitude, longitude, altitudeMeters, declination) {
  const lat = Number(latitude);
  const lon = Number(longitude);
  const latStr = `${Math.abs(lat).toFixed(4)}°${lat >= 0 ? 'N' : 'S'}`;
  const lonStr = `${Math.abs(lon).toFixed(4)}°${lon >= 0 ? 'E' : 'W'}`;
  const altStr = (altitudeMeters !== undefined && altitudeMeters !== null && !isNaN(altitudeMeters) && altitudeMeters !== 0)
    ? ` · 海拔 ${Math.round(altitudeMeters)}m`
    : '';
  const dirStr = declination < 0 ? '西偏' : (declination > 0 ? '东偏' : '无偏');
  const declText = `${dirStr}${Math.abs(declination).toFixed(1)}°`;

  return {
    coordsDesc: `${latStr}, ${lonStr}${altStr}`,
    declText,
    dirStr,
    declAbs: Math.abs(declination).toFixed(1)
  };
}

module.exports = {
  computeGeomagneticField,
  computeDeclination,
  computeFieldStrength,
  formatLocationAndDeclination
};
