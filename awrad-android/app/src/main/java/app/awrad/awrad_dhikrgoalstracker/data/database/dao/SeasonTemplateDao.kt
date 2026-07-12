package app.awrad.awrad_dhikrgoalstracker.data.database.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.SeasonTemplateDayEntity
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.SeasonTemplateEntity
import app.awrad.awrad_dhikrgoalstracker.data.model.SeasonTemplateCode

@Dao
interface SeasonTemplateDao {

    @Query("SELECT * FROM season_templates ORDER BY code")
    suspend fun getTemplates(): List<SeasonTemplateEntity>

    @Query("SELECT * FROM season_template_days WHERE templateCode = :code ORDER BY dayOfMonth")
    suspend fun getDays(code: SeasonTemplateCode): List<SeasonTemplateDayEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertTemplates(templates: List<SeasonTemplateEntity>)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertDays(days: List<SeasonTemplateDayEntity>)
}
