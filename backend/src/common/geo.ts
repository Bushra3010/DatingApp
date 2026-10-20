/** SQL expression for great-circle distance in km between (lat1,lng1) and (lat2,lng2). */
export function distanceKmSql(lat1: string, lng1: string, lat2: string, lng2: string): string {
  return `(6371 * 2 * asin(sqrt(
    power(sin(radians(${lat2} - ${lat1}) / 2), 2) +
    cos(radians(${lat1})) * cos(radians(${lat2})) * power(sin(radians(${lng2} - ${lng1}) / 2), 2)
  )))`;
}

/** Distance as shown to other users: rounded, never exact (section 5, privacy). */
export function displayDistance(km: number | null): string | null {
  if (km === null || Number.isNaN(km)) return null;
  if (km < 2) return 'Less than 2 km away';
  if (km < 10) return `${Math.round(km)} km away`;
  return `${Math.round(km / 5) * 5} km away`;
}

export function ageFrom(birthDate: Date | string, now = new Date()): number {
  const d = new Date(birthDate);
  let age = now.getUTCFullYear() - d.getUTCFullYear();
  const m = now.getUTCMonth() - d.getUTCMonth();
  if (m < 0 || (m === 0 && now.getUTCDate() < d.getUTCDate())) age--;
  return age;
}
