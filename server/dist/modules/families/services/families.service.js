import { db } from "../../../shared/db/sqlite.js";
import { NotFoundError } from "../../../shared/errors/appError.js";
function elderlyForFamily(familyId) {
    const rows = db
        .prepare("SELECT id, first_name, address, neighborhood, lat, lng FROM elderly_profiles WHERE family_id = ?")
        .all(familyId);
    return rows.map((r) => ({
        id: r.id,
        firstName: r.first_name,
        address: r.address,
        neighborhood: r.neighborhood,
        lat: r.lat,
        lng: r.lng,
    }));
}
export const familiesService = {
    me(auth) {
        if (!auth.familyId)
            throw new NotFoundError("No perteneces a una familia");
        const family = db
            .prepare("SELECT id, name, family_code FROM families WHERE id = ?")
            .get(auth.familyId);
        if (!family)
            throw new NotFoundError("Familia no encontrada");
        return {
            id: family.id,
            name: family.name,
            familyCode: family.family_code,
            elderly: elderlyForFamily(family.id),
        };
    },
    join(auth, data) {
        const family = db
            .prepare("SELECT id, name, family_code FROM families WHERE family_code = ?")
            .get(data.code.trim().toUpperCase());
        if (!family)
            throw new NotFoundError("Código de familia no encontrado");
        db.prepare("UPDATE elderly_profiles SET family_id = ? WHERE user_id = ?").run(family.id, auth.id);
        return {
            id: family.id,
            name: family.name,
            familyCode: family.family_code,
            elderly: elderlyForFamily(family.id),
        };
    },
};
//# sourceMappingURL=families.service.js.map